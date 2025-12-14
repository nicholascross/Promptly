import Foundation
@testable import PromptlyKit
import Testing

struct ResponseStreamCollectorTests {
    @Test
    func collectsTextDeltasAndFinishesWithResponse() throws {
        var streamed = ""
        var collector = ResponseStreamCollector(
            decoder: JSONDecoder(),
            onTextStream: { streamed += $0 }
        )

        let delta1 = #"{"type":"response.output_text.delta","delta":{"text":"Hel"},"output_index":0,"response_id":"r1"}"#
        let delta2 = #"{"type":"response.output_text.delta","delta":{"text":"lo"},"output_index":0,"response_id":"r1"}"#
        let completed = #"{"type":"response.completed","response":{"id":"r1","status":"completed"}}"#

        try collector.handle(event: nil, data: delta1)
        try collector.handle(event: nil, data: delta2)
        try collector.handle(event: nil, data: completed)

        let completion = try collector.finish()
        #expect(streamed == "Hello")
        #expect(completion.responseId == "r1")
        #expect(completion.response?.id == "r1")
        #expect(completion.streamedOutputs[0] == "Hello")
    }
}

