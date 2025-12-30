import Foundation

public struct PromptMessage: Codable, Sendable {
    public let role: PromptRole
    public let content: PromptContent
    public let toolCalls: [PromptToolCall]?
    public let toolCallId: String?

    public init(
        role: PromptRole,
        content: PromptContent,
        toolCalls: [PromptToolCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }
}
