import Foundation
@testable import PromptlyKit
import PromptlyOpenAIClient
import PromptlyKitCommunication
import Testing
import PromptlyKitUtils

struct ChatCompletionsPromptEndpointTests {
    @Test
    func returnsToolCallTurnAndContinuationMessages() async throws {
        let transport = TestNetworkTransport(
            nextLineStream: [
                #"data: {"choices":[{"delta":{"tool_calls":[{"id":"call_1","function":{"name":"MyTool","arguments":"{\"a\":"}}]},"finish_reason":null}]}"#,
                #"data: {"choices":[{"delta":{"tool_calls":[{"function":{"arguments":"1}"}}]},"finish_reason":"tool_calls"}]}"#
            ]
        )

        let factory = ChatCompletionsRequestFactory(
            chatCompletionURL: URL(string: "https://example.com/v1/chat/completions")!,
            model: "gpt-test",
            token: "token",
            organizationId: nil,
            tools: [],
            encoder: JSONEncoder()
        )

        let endpoint = ChatCompletionsPromptEndpoint(
            factory: factory,
            transport: transport,
            encoder: JSONEncoder()
        )

        let turn = try await endpoint.prompt(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { _ in }
        )

        #expect(turn.toolCalls.count == 1)
        #expect(turn.toolCalls.first?.id == "call_1")
        #expect(turn.toolCalls.first?.name == "MyTool")

        guard case let .chatCompletions(messages)? = turn.context else {
            Issue.record("Expected chatCompletions continuation with messages")
            return
        }

        #expect(messages.count == 2)
        #expect(messages.last?.role == .assistant)
        #expect(messages.last?.toolCalls?.count == 1)
        #expect(messages.last?.toolCalls?.first?.function.name == "MyTool")
    }

    @Test
    func returnsAllToolCallsInSingleTurn() async throws {
        let transport = TestNetworkTransport(
            nextLineStream: [
                #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"FirstTool","arguments":"{\"a\":"}},{"index":1,"id":"call_2","function":{"name":"SecondTool","arguments":"{\"b\":"}}]},"finish_reason":null}]}"#,
                #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"1}"}},{"index":1,"function":{"arguments":"2}"}}]},"finish_reason":"tool_calls"}]}"#
            ]
        )

        let factory = ChatCompletionsRequestFactory(
            chatCompletionURL: URL(string: "https://example.com/v1/chat/completions")!,
            model: "gpt-test",
            token: "token",
            organizationId: nil,
            tools: [],
            encoder: JSONEncoder()
        )

        let endpoint = ChatCompletionsPromptEndpoint(
            factory: factory,
            transport: transport,
            encoder: JSONEncoder()
        )

        let turn = try await endpoint.prompt(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { _ in }
        )

        #expect(turn.toolCalls.count == 2)
        #expect(turn.toolCalls[0].id == "call_1")
        #expect(turn.toolCalls[0].name == "FirstTool")
        #expect(turn.toolCalls[1].id == "call_2")
        #expect(turn.toolCalls[1].name == "SecondTool")

        guard case let .chatCompletions(messages)? = turn.context else {
            Issue.record("Expected chatCompletions continuation with messages")
            return
        }

        #expect(messages.count == 2)
        #expect(messages.last?.role == .assistant)
        #expect(messages.last?.toolCalls?.count == 2)
        #expect(messages.last?.toolCalls?[0].function.name == "FirstTool")
        #expect(messages.last?.toolCalls?[1].function.name == "SecondTool")
    }
}

private final class TestNetworkTransport: NetworkTransport, Sendable {
    private let nextLineStream: [String]

    init(nextLineStream: [String]) {
        self.nextLineStream = nextLineStream
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(), response)
    }

    func lineStream(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in nextLineStream {
                continuation.yield(line)
            }
            continuation.finish()
        }

        return (stream, response)
    }
}
