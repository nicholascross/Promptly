import Foundation

public struct ChatMessage: Codable, Sendable {
    public let role: ChatRole
    public let id: String?
    public let content: Content
    public let toolCalls: [ChatFunctionCall]?
    public let toolCallId: String?

    public init(
        role: ChatRole,
        id: String? = nil,
        content: Content,
        toolCalls: [ChatFunctionCall]? = nil,
        toolCallId: String? = nil
    ) {
        self.role = role
        self.id = id
        self.content = content
        self.toolCalls = toolCalls
        self.toolCallId = toolCallId
    }

    enum CodingKeys: String, CodingKey {
        case role, id, content
        case toolCalls = "tool_calls"
        case toolCallId = "tool_call_id"
    }
}
