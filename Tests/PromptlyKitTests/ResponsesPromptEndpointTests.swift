import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct ResponsesPromptEndpointTests {
    @Test
    func streamsAssistantTextAndReturnsCompletedTurn() async throws {
        let transport = TestResponsesTransport(
            lineStream: [
                "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"text\":\"Hel\"},\"output_index\":0,\"response_id\":\"r1\"}",
                "data: {\"type\":\"response.output_text.delta\",\"delta\":{\"text\":\"lo\"},\"output_index\":0,\"response_id\":\"r1\"}",
                "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"r1\",\"status\":\"completed\",\"output\":[{\"type\":\"message\",\"content\":[{\"type\":\"output_text\",\"text\":\"Hello\"}]}]}}",
            ],
            dataResponseBody: #"{"id":"r1","status":"completed","output":[{"type":"message","content":[{"type":"output_text","text":"Hello"}]}]}"#
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let requestFactory = ResponsesRequestFactory(
            responsesURL: URL(string: "https://example.com/v1/responses")!,
            model: "gpt-test",
            token: "token",
            organizationId: nil,
            tools: [],
            encoder: encoder
        )

        let client = ResponsesClient(factory: requestFactory, decoder: decoder, transport: transport)
        let endpoint = ResponsesPromptEndpoint(client: client, encoder: encoder, decoder: decoder)

        let events = EventCollector()
        let turn = try await endpoint.prompt(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { event in
                await events.append(event)
            }
        )

        #expect(turn.toolCalls.isEmpty)
        #expect(turn.context == nil)

        let snapshot = await events.snapshot()
        #expect(snapshot.contains { event in
            if case let .assistantTextDelta(text) = event { return text == "Hel" || text == "lo" }
            return false
        })
    }

    @Test
    func returnsToolCallTurnAndContinuation() async throws {
        let transport = TestResponsesTransport(
            lineStream: [
                "data: {\"type\":\"response.requires_action\",\"response\":{\"id\":\"r2\",\"status\":\"requires_action\",\"required_action\":{\"type\":\"submit_tool_outputs\",\"submit_tool_outputs\":{\"tool_calls\":[{\"call_id\":\"call_1\",\"type\":\"function\",\"function\":{\"name\":\"Echo\",\"arguments\":\"{\\\"a\\\":1}\"}}]}}}}",
                ""
            ],
            dataResponseBody: #"{"id":"r2","status":"requires_action","required_action":{"type":"submit_tool_outputs","submit_tool_outputs":{"tool_calls":[{"call_id":"call_1","type":"function","function":{"name":"Echo","arguments":"{\"a\":1}"}}]}}}"#
        )

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        let requestFactory = ResponsesRequestFactory(
            responsesURL: URL(string: "https://example.com/v1/responses")!,
            model: "gpt-test",
            token: "token",
            organizationId: nil,
            tools: [],
            encoder: encoder
        )

        let client = ResponsesClient(factory: requestFactory, decoder: decoder, transport: transport)
        let endpoint = ResponsesPromptEndpoint(client: client, encoder: encoder, decoder: decoder)

        let turn = try await endpoint.prompt(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { _ in }
        )

        #expect(turn.toolCalls.count == 1)
        #expect(turn.toolCalls.first?.id == "call_1")
        #expect(turn.toolCalls.first?.name == "Echo")

        guard case let .responses(previousResponseIdentifier)? = turn.context else {
            Issue.record("Expected responses continuation")
            return
        }
        #expect(previousResponseIdentifier == "r2")
    }
}

private final class TestResponsesTransport: NetworkTransport, Sendable {
    private let lineStreamLines: [String]
    private let dataResponseBody: String

    init(lineStream: [String], dataResponseBody: String) {
        self.lineStreamLines = lineStream
        self.dataResponseBody = dataResponseBody
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!
        return (Data(dataResponseBody.utf8), response)
    }

    func lineStream(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in lineStreamLines {
                continuation.yield(line)
            }
            continuation.finish()
        }

        return (stream, response)
    }
}

private actor EventCollector {
    private var storage: [PromptStreamEvent] = []

    func append(_ event: PromptStreamEvent) {
        storage.append(event)
    }

    func snapshot() -> [PromptStreamEvent] {
        storage
    }
}
