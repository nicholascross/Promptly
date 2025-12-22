import Foundation

struct ChatMessage: Codable, Sendable {
    let role: ChatRole
    let id: String?
    let content: Content
    let toolCalls: [ChatFunctionCall]?
    let toolCallId: String?

    init(
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

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        let encodedRole: String
        switch role {
        case .tool:
            encodedRole = "developer"
        default:
            encodedRole = role.rawValue
        }

        try container.encode(encodedRole, forKey: .role)
        try container.encodeIfPresent(id, forKey: .id)

        try container.encode(content.blocks(for: role), forKey: .content)
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(ChatRole.self, forKey: .role)
        id = try container.decodeIfPresent(String.self, forKey: .id)
        toolCalls = try container.decodeIfPresent([ChatFunctionCall].self, forKey: .toolCalls)
        toolCallId = try container.decodeIfPresent(String.self, forKey: .toolCallId)

        if let blocks = try? container.decode([ContentBlock].self, forKey: .content) {
            if blocks.isEmpty {
                content = .empty
            } else if blocks.count == 1, let block = blocks.first, let text = block.text {
                content = .text(text)
            } else {
                content = .blocks(blocks)
            }
        } else if let text = try? container.decode(String.self, forKey: .content) {
            content = .text(text)
        } else {
            content = .empty
        }

    }
}
