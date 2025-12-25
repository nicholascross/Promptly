import Foundation
@testable import PromptlySubAgents
@testable import PromptlyKit
import PromptlyKitUtils
import Testing

struct SubAgentRunnerTests {
    @Test
    func filtersDisallowedToolNamesAndKeepsRequiredSubAgentTools() throws {
        try withTestTokenEnvironment {
            let fileManager = InMemoryFileManager()
            let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
            let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
            try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

            let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
            try writeJSONValue(baseConfiguration, to: configurationFileURL, fileManager: fileManager)

            let agentConfiguration = makeAgentConfigurationJSON(
                name: "Tooling Agent",
                description: "Test tool filtering.",
                systemPrompt: "Use tools carefully."
            )
            let agentFileURL = agentsDirectoryURL.appendingPathComponent("tooling.json")
            try writeJSONValue(agentConfiguration, to: agentFileURL, fileManager: fileManager)

            let loader = SubAgentConfigurationLoader(fileManager: fileManager)
            let configuration = try loader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentFileURL
            )

            let emptySchema = JSONSchema.object(
                requiredProperties: [:],
                optionalProperties: [:],
                description: nil
            )

            let shellCommandConfig = ShellCommandConfig(shellCommands: [
                ShellCommandConfigEntry(
                    name: "EchoTool",
                    description: "Echo tool for testing.",
                    executable: "/usr/bin/true",
                    echoOutput: nil,
                    truncateOutput: nil,
                    argumentTemplate: [["--version"]],
                    exclusiveArgumentTemplate: nil,
                    optIn: nil,
                    parameters: emptySchema
                ),
                ShellCommandConfigEntry(
                    name: "SubAgent.fake",
                    description: "Disallowed tool.",
                    executable: "/usr/bin/true",
                    echoOutput: nil,
                    truncateOutput: nil,
                    argumentTemplate: [["--version"]],
                    exclusiveArgumentTemplate: nil,
                    optIn: nil,
                    parameters: emptySchema
                ),
                ShellCommandConfigEntry(
                    name: ReturnToSupervisorTool.toolName,
                    description: "Reserved tool.",
                    executable: "/usr/bin/true",
                    echoOutput: nil,
                    truncateOutput: nil,
                    argumentTemplate: [["--version"]],
                    exclusiveArgumentTemplate: nil,
                    optIn: nil,
                    parameters: emptySchema
                ),
                ShellCommandConfigEntry(
                    name: ReportProgressToSupervisorTool.toolName,
                    description: "Reserved tool.",
                    executable: "/usr/bin/true",
                    echoOutput: nil,
                    truncateOutput: nil,
                    argumentTemplate: [["--version"]],
                    exclusiveArgumentTemplate: nil,
                    optIn: nil,
                    parameters: emptySchema
                )
            ])

            let localToolsConfigURL = fileManager.currentDirectoryURL.appendingPathComponent("tools.json")
            try writeShellCommandConfig(shellCommandConfig, to: localToolsConfigURL, fileManager: fileManager)

            let toolSettings = SubAgentToolSettings(
                defaultToolsConfigURL: fileManager.currentDirectoryURL.appendingPathComponent("default-tools.json"),
                localToolsConfigURL: localToolsConfigURL,
                includeTools: [],
                excludeTools: []
            )

            let runner = SubAgentRunner(
                configuration: configuration,
                toolSettings: toolSettings,
                logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
                toolOutput: { _ in },
                fileManager: fileManager
            )

            let tools = try runner.makeTools(transcriptLogger: nil)
            let toolNames = tools.map { $0.name }

            #expect(toolNames.contains("EchoTool"))
            #expect(!toolNames.contains("SubAgent.fake"))

            let returnToolCount = toolNames.filter { $0 == ReturnToSupervisorTool.toolName }.count
            let progressToolCount = toolNames.filter { $0 == ReportProgressToSupervisorTool.toolName }.count

            #expect(returnToolCount == 1)
            #expect(progressToolCount == 1)
        }
    }

    @Test
    func throwsWhenReturnPayloadIsMissingAndLogsRuntimeStop() async throws {
        try await withTestTokenEnvironment {
            let fileManager = InMemoryFileManager()
            let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
            let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
            try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

            let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
            try writeJSONValue(baseConfiguration, to: configurationFileURL, fileManager: fileManager)

            let agentConfiguration = makeAgentConfigurationJSON(
                name: "Return Agent",
                description: "Test return enforcement.",
                systemPrompt: "Always return payloads."
            )
            let agentFileURL = agentsDirectoryURL.appendingPathComponent("return.json")
            try writeJSONValue(agentConfiguration, to: agentFileURL, fileManager: fileManager)

            let loader = SubAgentConfigurationLoader(fileManager: fileManager)
            let configuration = try loader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentFileURL
            )

            let toolSettings = SubAgentToolSettings(
                defaultToolsConfigURL: fileManager.currentDirectoryURL.appendingPathComponent("default-tools.json"),
                localToolsConfigURL: fileManager.currentDirectoryURL.appendingPathComponent("local-tools.json"),
                includeTools: [],
                excludeTools: []
            )

            let transcript = [
                PromptTranscriptEntry.assistant(message: "No return tool call")
            ]
            let stubCoordinator = StubCoordinator(result: PromptSessionResult(promptTranscript: transcript))

            let runner = SubAgentRunner(
                configuration: configuration,
                toolSettings: toolSettings,
                logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
                toolOutput: { _ in },
                fileManager: fileManager,
                coordinatorFactory: { _ in stubCoordinator }
            )

            let request = SubAgentToolRequest(
                task: "Summarize the changes",
                contextPack: nil,
                goals: nil,
                constraints: nil
            )

            do {
                _ = try await runner.run(request: request)
                Issue.record("Expected missing return payload error.")
            } catch let error as SubAgentToolError {
                switch error {
                case let .missingReturnPayload(agentName):
                    #expect(agentName == "Return Agent")
                }
            } catch {
                Issue.record("Unexpected error: \(error)")
            }

            let logFiles = try fileManager.contentsOfDirectory(
                at: runnerLogDirectory(directoryURL: fileManager.currentDirectoryURL),
                includingPropertiesForKeys: nil,
                options: []
            )
            let logFileURL = logFiles.first { $0.pathExtension == "jsonl" }
            if let logFileURL {
                let entries = try loadJSONLines(from: logFileURL, fileManager: fileManager)
                let runtimeStopEntry = entries.first { entry in
                    guard case let .object(object) = entry else { return false }
                    return stringValue(object["eventType"]) == "runtime_stop"
                }
                if case let .object(runtimeObject)? = runtimeStopEntry,
                   case let .object(dataObject)? = runtimeObject["data"] {
                    #expect(stringValue(dataObject["status"]) == "missing_return_payload")
                } else {
                    Issue.record("Expected runtime_stop entry.")
                }
            } else {
                Issue.record("Expected log file to be created.")
            }
        }
    }
}

private struct StubCoordinator: SubAgentCoordinator {
    let result: PromptSessionResult

    func run(
        messages: [PromptMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        result
    }
}

private func runnerLogDirectory(directoryURL: URL) -> URL {
    directoryURL.appendingPathComponent("logs", isDirectory: true)
}
