import Foundation

public struct ResponsesRequestFactory {
    private let responsesURL: URL
    private let model: String?
    private let token: String?
    private let organizationId: String?
    private let tools: [OpenAIToolDefinition]
    private let encoder: JSONEncoder

    public init(
        responsesURL: URL,
        model: String?,
        token: String?,
        organizationId: String?,
        tools: [OpenAIToolDefinition],
        encoder: JSONEncoder
    ) {
        self.responsesURL = responsesURL
        self.model = model
        self.token = token
        self.organizationId = organizationId
        self.tools = tools
        self.encoder = encoder
    }

    public func makeCreateRequest(items: [RequestItem], previousResponseId: String?, stream: Bool) throws -> URLRequest {
        var request = URLRequest(url: responsesURL)
        request.httpMethod = "POST"
        applyDefaultHeaders(to: &request, accept: stream ? "text/event-stream" : "application/json")

        let body = ResponseRequest(
            model: model,
            input: items,
            stream: stream,
            tools: toolSpecs,
            toolChoice: toolSpecs != nil ? .auto : nil,
            previousResponseId: previousResponseId
        )
        request.httpBody = try encoder.encode(body)
        return request
    }

    public func makeRetrieveRequest(responseId: String) -> URLRequest {
        var request = URLRequest(url: responsesURL.appendingPathComponent(responseId))
        request.httpMethod = "GET"
        applyDefaultHeaders(to: &request, accept: "application/json")
        return request
    }

    private var toolSpecs: [ToolSpec]? {
        guard !tools.isEmpty else { return nil }
        return tools.map { tool in
            ToolSpec(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        }
    }

    private func applyDefaultHeaders(to request: inout URLRequest, accept: String) {
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue(accept, forHTTPHeaderField: "Accept")
        request.addValue("promptly", forHTTPHeaderField: "User-Agent")
        request.addValue("responses=v1", forHTTPHeaderField: "OpenAI-Beta")

        if let token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        if let organizationId {
            request.addValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }
    }
}
