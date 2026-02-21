import Foundation
@testable import PromptlyKit
import PromptlyOpenAIClient
import Testing

struct ResponseStreamCollectorTests {
    @Test
    func collectsTextDeltasAndFinishesWithResponse() async throws {
        let streamed = StreamedTextCollector()
        var collector = ResponseStreamCollector(
            decoder: JSONDecoder(),
            onTextStream: { text in
                await streamed.append(text)
            }
        )

        let delta1 = #"{"type":"response.output_text.delta","delta":{"text":"Hel"},"output_index":0,"response_id":"r1"}"#
        let delta2 = #"{"type":"response.output_text.delta","delta":{"text":"lo"},"output_index":0,"response_id":"r1"}"#
        let completed = #"{"type":"response.completed","response":{"id":"r1","status":"completed"}}"#

        try await collector.handle(event: nil, data: delta1)
        try await collector.handle(event: nil, data: delta2)
        try await collector.handle(event: nil, data: completed)

        let completion = try collector.finish()
        #expect(await streamed.snapshot() == "Hello")
        #expect(completion.responseId == "r1")
        #expect(completion.response?.id == "r1")
        #expect(completion.streamedOutputs[0] == "Hello")
    }
}

private actor StreamedTextCollector {
    private var value = ""

    func append(_ text: String) {
        value += text
    }

    func snapshot() -> String {
        value
    }
}
