import Foundation
import PromptlyKit
import PromptlyKitUtils
@preconcurrency import SwiftTokenizer

public struct ShellCommandTool: ExecutableTool, Sendable {
    public let name: String
    public let description: String
    public let executable: String
    public let parameters: JSONSchema

    private let echoOutput: Bool
    /// Whether to truncate large outputs by wrapping with log-slicing middleware when configured.
    internal let truncateOutput: Bool
    private let argumentTemplate: [[String]]
    private let exclusiveArgumentTemplate: Bool
    private let fileManager: any FileManagerProtocol
    private let sandboxURL: URL
    private let toolOutput: @Sendable (String) -> Void

    public init(
        name: String,
        description: String,
        executable: String,
        echoOutput: Bool,
        truncateOutput: Bool,
        parameters: JSONSchema,
        argumentTemplate: [[String]],
        exclusiveArgumentTemplate: Bool,
        sandboxURL: URL,
        fileManager: FileManagerProtocol,
        toolOutput: @Sendable @escaping (String) -> Void = { stream in
            fputs(stream, stdout)
            fflush(stdout)
        }
    ) {
        self.name = name
        self.description = description
        self.executable = executable
        self.echoOutput = echoOutput
        self.truncateOutput = truncateOutput
        self.parameters = parameters
        self.argumentTemplate = argumentTemplate
        self.exclusiveArgumentTemplate = exclusiveArgumentTemplate
        self.sandboxURL = sandboxURL
        self.fileManager = fileManager
        self.toolOutput = toolOutput
    }

    public func execute(arguments: JSONValue) async throws -> JSONValue {
        toolOutput("Executing shell command: \(executable) with arguments: \(arguments)\n")
        let runner = ProcessRunner(toolOutputHandler: toolOutput)
        let (exitCode, output) = try await runner.run(
            executable: executable,
            arguments: deriveExecutableArguments(arguments: arguments),
            currentDirectoryURL: fileManager.currentDirectoryURL,
            streamOutput: echoOutput
        )

        return .object([
            "exitCode": .number(Double(exitCode)),
            "output": .string(output)
        ])
    }

    private func validateRequiredParameter(_ propertyName: String) throws {
        guard case let .object(requiredProperties, _, _) = parameters else {
            // Ignoring misconfiguration, this should not happen
            // since parameters should be defined as an object schema.
            return
        }

        if requiredProperties.keys.contains(propertyName) {
            throw ShellCommandToolError.missingRequiredParameter(name: propertyName)
        }
    }

    private func validateSandboxPath(_ path: String) throws {
        let fullPath = sandboxURL.appendingPathComponent(path).standardizedFileURL
        guard fullPath.path.hasPrefix(sandboxURL.path) else {
            throw ShellCommandToolError.invalidSandboxPath(path: path)
        }
    }

    private func deriveExecutableArguments(arguments: JSONValue) async throws -> [String] {
        if exclusiveArgumentTemplate {
            for templateGroup in argumentTemplate {
                do {
                    let groupArgs = try await templateGroup.asyncMap { templateElement in
                        let template = try ArgumentTemplate(string: templateElement)
                        return try await template.resolveArguments(
                            arguments: arguments,
                            validateRequiredParameters: validateRequiredParameter,
                            validateSandboxPath: validateSandboxPath
                        )
                    }.compactMap { $0 }
                    return groupArgs
                } catch ShellCommandToolError.missingOptionalParameter(_) {
                    continue
                }
            }
            return []
        } else {
            return try await argumentTemplate.asyncFlatMap { templateGroup in
                do {
                    return try await templateGroup.asyncMap { templateElement in
                        let template = try ArgumentTemplate(string: templateElement)
                        return try await template.resolveArguments(
                            arguments: arguments,
                            validateRequiredParameters: validateRequiredParameter,
                            validateSandboxPath: validateSandboxPath
                        )
                    }.compactMap { $0 }
                } catch ShellCommandToolError.missingOptionalParameter(_) {
                    return [String]()
                }
            }
        }
    }
}
