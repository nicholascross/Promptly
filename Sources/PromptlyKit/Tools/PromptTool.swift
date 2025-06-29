import Foundation

/// A built-in tool to prompt the user for input directly, bypassing shell commands.
public struct PromptTool: ExecutableTool, Sendable {

    public let name = "prompt"
    public let description = "Prompt the user for input with a given message"

    public let parameters: JSONSchema = .object(
        requiredProperties: [
            "message": .string(
                minLength: nil,
                maxLength: nil,
                pattern: nil,
                format: nil,
                description: "Prompt message to display to the user"
            )
        ],
        optionalProperties: [
            "default": .string(
                minLength: nil,
                maxLength: nil,
                pattern: nil,
                format: nil,
                description: "Default value if user presses enter with no input"
            )
        ],
        description: "Prompt the user and return the input as a string"
    )

    public init() {}

    public func execute(arguments: JSONValue) async throws -> JSONValue {
        let promptToolArguments = try arguments.decoded(PromptToolArguments.self)
        fputs("\(promptToolArguments.message)\n", stdout)
        fflush(stdout)
        let input = readLine(strippingNewline: true) ?? ""
        if input.isEmpty, let def = promptToolArguments.default {
            return .string(def)
        }
        return .string(input)
    }
}

private struct PromptToolArguments: Decodable {
    let message: String
    let `default`: String?
}
