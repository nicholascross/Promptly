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

enum PromptContinuation: Sendable {
    case responses(previousResponseId: String)
    case chatCompletions(messages: [ChatMessage])
}

struct PromptTurn: Sendable {
    public let continuation: PromptContinuation?
    public let toolCalls: [ToolCallRequest]
    public let finalAssistantText: String?

    public var isComplete: Bool {
        toolCalls.isEmpty && finalAssistantText != nil
    }

    public init(
        continuation: PromptContinuation?,
        toolCalls: [ToolCallRequest],
        finalAssistantText: String?
    ) {
        self.continuation = continuation
        self.toolCalls = toolCalls
        self.finalAssistantText = finalAssistantText
    }
}

protocol PromptEndpoint {
    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn

    func continueSession(
        continuation: PromptContinuation,
        toolOutputs: [ToolCallOutput],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn
}
