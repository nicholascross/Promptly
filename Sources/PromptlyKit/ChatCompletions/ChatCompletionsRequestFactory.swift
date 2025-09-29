import Foundation

struct ChatCompletionsRequestFactory {
    private let chatCompletionURL: URL
    private let model: String?
    private let token: String?
    private let organizationId: String?
    private let tools: [any ExecutableTool]
    private let encoder: JSONEncoder

    init(
        chatCompletionURL: URL,
        model: String?,
        token: String?,
        organizationId: String?,
        tools: [any ExecutableTool],
        encoder: JSONEncoder
    ) {
        self.chatCompletionURL = chatCompletionURL
        self.model = model
        self.token = token
        self.organizationId = organizationId
        self.tools = tools
        self.encoder = encoder
    }

    func makeRequest(messages: [ChatMessage], toolChoice: ToolChoice = .auto) throws -> URLRequest {
        var request = URLRequest(url: chatCompletionURL)

        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("promptly", forHTTPHeaderField: "User-Agent")

        if let token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let organizationId {
            request.addValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }

        let toolSpecs: [ToolSpecPayload]? = tools.isEmpty ? nil : tools.map { tool in
            ToolSpecPayload(function: .init(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            ))
        }

        let toolChoiceValue: String? = toolSpecs != nil ? toolChoice.rawValue : nil

        let payload = Payload(
            model: model,
            messages: messages.map(MessagePayload.init),
            stream: true,
            tools: toolSpecs,
            toolChoice: toolChoiceValue
        )

        request.httpBody = try encoder.encode(payload)

        return request
    }
}

private extension ChatCompletionsRequestFactory {
    struct Payload: Encodable {
        let model: String?
        let messages: [MessagePayload]
        let stream: Bool
        let tools: [ToolSpecPayload]?
        let toolChoice: String?

        enum CodingKeys: String, CodingKey {
            case model, messages, stream, tools
            case toolChoice = "tool_choice"
        }
    }

    struct ToolSpecPayload: Encodable {
        let type = "function"
        let function: ToolFunction

        struct ToolFunction: Encodable {
            let name: String
            let description: String
            let parameters: JSONSchema
        }
    }

    struct MessagePayload: Encodable {
        let role: ChatRole
        let id: String?
        let content: Content
        let toolCalls: [ChatFunctionCall]?
        let toolCallId: String?

        init(_ message: ChatMessage) {
            self.role = message.role
            self.id = message.id
            self.content = message.content
            self.toolCalls = message.toolCalls
            self.toolCallId = message.toolCallId
        }

        enum CodingKeys: String, CodingKey {
            case role, id, content
            case toolCalls = "tool_calls"
            case toolCallId = "tool_call_id"
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(role.rawValue, forKey: .role)
            try container.encodeIfPresent(id, forKey: .id)
            try container.encode(content, forKey: .content)
            try container.encodeIfPresent(toolCalls, forKey: .toolCalls)
            try container.encodeIfPresent(toolCallId, forKey: .toolCallId)
        }
    }
}
