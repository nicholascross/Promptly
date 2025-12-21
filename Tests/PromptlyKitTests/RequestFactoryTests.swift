import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct RequestFactoryTests {
    @Test
    func responsesRequestFactorySetsHeadersAndBody() throws {
        let tools: [any ExecutableTool] = []
        let factory = ResponsesRequestFactory(
            responsesURL: URL(string: "https://example.com/v1/responses")!,
            model: "gpt-test",
            token: "token",
            organizationId: "org",
            tools: tools,
            encoder: JSONEncoder()
        )

        let request = try factory.makeCreateRequest(items: [], previousResponseId: nil, stream: false)

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Accept") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "OpenAI-Organization") == "org")
        #expect(request.value(forHTTPHeaderField: "OpenAI-Beta") == "responses=v1")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "promptly")

        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: body)
        expectString(decoded["model"], equals: "gpt-test")
        expectBool(decoded["stream"], equals: false)
    }

    @Test
    func chatCompletionsRequestFactorySetsHeadersAndBody() throws {
        let tools: [any ExecutableTool] = []
        let factory = ChatCompletionsRequestFactory(
            chatCompletionURL: URL(string: "https://example.com/v1/chat/completions")!,
            model: "gpt-test",
            token: "token",
            organizationId: "org",
            tools: tools,
            encoder: JSONEncoder()
        )

        let request = try factory.makeRequest(messages: [ChatMessage(role: .user, content: .text("hi"))])

        #expect(request.httpMethod == "POST")
        #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")
        #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer token")
        #expect(request.value(forHTTPHeaderField: "OpenAI-Organization") == "org")
        #expect(request.value(forHTTPHeaderField: "User-Agent") == "promptly")

        let body = try #require(request.httpBody)
        let decoded = try JSONDecoder().decode([String: JSONValue].self, from: body)
        expectString(decoded["model"], equals: "gpt-test")
        expectBool(decoded["stream"], equals: true)
    }
}
