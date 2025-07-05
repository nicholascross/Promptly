import Foundation

struct ChatRequestFactory {
    private let chatCompletionsURL: URL
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
        chatCompletionsURL = chatCompletionURL
        self.model = model
        self.token = token
        self.organizationId = organizationId
        self.tools = tools
        self.encoder = encoder
    }

    func makeRequest(messages: [ChatMessage], toolChoice: ToolChoice = .auto) throws -> URLRequest {
        var request = URLRequest(url: chatCompletionsURL)

        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let org = organizationId {
            request.addValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }

        let toolSpecs: [ToolSpec]? = tools.isEmpty ? nil : tools.map { tool in
            .init(function: .init(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            ))
        }

        // Only send tool_choice when tools are provided, else omit to satisfy API requirements
        let chatRequest = ChatRequest(
            model: model,
            messages: messages,
            stream: true,
            tools: toolSpecs,
            toolChoice: toolSpecs != nil ? toolChoice : nil
        )

        request.httpBody = try encoder.encode(chatRequest)

        return request
    }
}
