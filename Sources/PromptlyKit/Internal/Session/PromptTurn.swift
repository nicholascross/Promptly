import Foundation

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
