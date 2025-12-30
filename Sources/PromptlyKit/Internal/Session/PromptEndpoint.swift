import Foundation
import PromptlyKitUtils

struct ToolCallRequest: Sendable {
    public let id: String
    public let name: String
    public let arguments: JSONValue

    public init(id: String, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}

struct ToolCallOutput: Sendable {
    public let id: String
    public let output: JSONValue

    public init(id: String, output: JSONValue) {
        self.id = id
        self.output = output
    }
}

enum PromptContext: Sendable {
    case responses(previousResponseIdentifier: String)
    case chatCompletions(messages: [ChatMessage])
}

enum PromptEntry: Sendable {
    case initial(messages: [ChatMessage])
    case resume(context: PromptContext, requestMessages: [ChatMessage])
    case toolCallResults(context: PromptContext, toolOutputs: [ToolCallOutput])
}

struct PromptTurn: Sendable {
    public let context: PromptContext?
    public let toolCalls: [ToolCallRequest]
    public let resumeToken: String?

    public var isComplete: Bool {
        toolCalls.isEmpty && context == nil
    }

    public init(
        context: PromptContext?,
        toolCalls: [ToolCallRequest],
        resumeToken: String?
    ) {
        self.context = context
        self.toolCalls = toolCalls
        self.resumeToken = resumeToken
    }
}

protocol PromptEndpoint {
    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn
}
