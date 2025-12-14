import Foundation
@testable import PromptlyKit
import Testing

struct ChatCompletionsResponseProcessorTests {
    @Test
    func emitsContentEventsFromStreamingDeltas() async throws {
        let processor = ChatCompletionsResponseProcessor()

        let line1 = #"data: {"choices":[{"delta":{"content":"Hel"},"finish_reason":null}]}"#
        let line2 = #"data: {"choices":[{"delta":{"content":"lo"},"finish_reason":"stop"}]}"#

        let events1 = try await processor.process(line: line1)
        #expect(events1.count == 1)
        if case let .content(text) = events1.first {
            #expect(text == "Hel")
        } else {
            Issue.record("Expected first event to be .content")
        }

        let events2 = try await processor.process(line: line2)
        #expect(events2.contains { event in
            if case .content = event { return true }
            return false
        })
        #expect(events2.contains { event in
            if case .stop = event { return true }
            return false
        })
    }

    @Test
    func assemblesToolCallArgumentsAcrossChunks() async throws {
        let processor = ChatCompletionsResponseProcessor()

        let chunk1 = #"data: {"choices":[{"delta":{"tool_calls":[{"id":"call_1","function":{"name":"MyTool","arguments":"{\"a\":"}}]},"finish_reason":null}]}"#
        let chunk2 = #"data: {"choices":[{"delta":{"tool_calls":[{"function":{"arguments":"1}"}}]},"finish_reason":"tool_calls"}]}"#

        _ = try await processor.process(line: chunk1)
        let events = try await processor.process(line: chunk2)

        #expect(events.count == 1)
        guard case let .toolCall(id, name, args) = events.first else {
            Issue.record("Expected a .toolCall event")
            return
        }

        #expect(id == "call_1")
        #expect(name == "MyTool")

        guard case let .object(dict) = args else {
            Issue.record("Expected tool call args to decode as an object")
            return
        }

        expectInteger(dict["a"], equals: 1)
    }
}
