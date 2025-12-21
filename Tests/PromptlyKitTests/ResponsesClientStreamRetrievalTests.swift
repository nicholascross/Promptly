import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct ResponsesClientStreamRetrievalTests {
    @Test
    func retrievesFullResponseWhenCompletedEventLacksOutput() async throws {
        let transport = TestResponsesClientTransport(
            streamLines: [
                "data: {\"type\":\"response.completed\",\"response\":{\"id\":\"r1\",\"status\":\"completed\"}}",
                ""
            ],
            retrievedResponseBody: #"{"id":"r1","status":"completed","output_text":"Hello"}"#
        )

        let factory = ResponsesRequestFactory(
            responsesURL: URL(string: "https://example.com/v1/responses")!,
            model: "gpt-test",
            token: "token",
            organizationId: nil,
            tools: [],
            encoder: JSONEncoder()
        )

        let client = ResponsesClient(factory: factory, decoder: JSONDecoder(), transport: transport)
        let result = try await client.createResponse(items: [], previousResponseId: nil, onTextStream: { _ in })
        #expect(result.response.combinedOutputText() == "Hello")
    }
}

private final class TestResponsesClientTransport: NetworkTransport, @unchecked Sendable {
    private let streamLines: [String]
    private let retrievedResponseBody: String

    init(streamLines: [String], retrievedResponseBody: String) {
        self.streamLines = streamLines
        self.retrievedResponseBody = retrievedResponseBody
    }

    func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        return (Data(retrievedResponseBody.utf8), response)
    }

    func lineStream(for request: URLRequest) async throws -> (AsyncThrowingStream<String, Error>, URLResponse) {
        let response = HTTPURLResponse(
            url: request.url ?? URL(string: "https://example.com")!,
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
        )!

        let stream = AsyncThrowingStream<String, Error> { continuation in
            for line in streamLines {
                continuation.yield(line)
            }
            continuation.finish()
        }

        return (stream, response)
    }
}

