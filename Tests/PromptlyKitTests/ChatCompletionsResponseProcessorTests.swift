import Foundation
@testable import PromptlyKit
import PromptlyOpenAIClient
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

    @Test
    func emitsMultipleToolCallsFromSingleTurn() async throws {
        let processor = ChatCompletionsResponseProcessor()

        let chunk1 = #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"id":"call_1","function":{"name":"FirstTool","arguments":"{\"a\":"}},{"index":1,"id":"call_2","function":{"name":"SecondTool","arguments":"{\"b\":"}}]},"finish_reason":null}]}"#
        let chunk2 = #"data: {"choices":[{"delta":{"tool_calls":[{"index":0,"function":{"arguments":"1}"}},{"index":1,"function":{"arguments":"2}"}}]},"finish_reason":"tool_calls"}]}"#

        _ = try await processor.process(line: chunk1)
        let events = try await processor.process(line: chunk2)

        #expect(events.count == 2)

        guard case let .toolCall(id1, name1, args1) = events[0] else {
            Issue.record("Expected first event to be .toolCall")
            return
        }

        #expect(id1 == "call_1")
        #expect(name1 == "FirstTool")

        guard case let .object(dict1) = args1 else {
            Issue.record("Expected first tool call args to decode as an object")
            return
        }
        expectInteger(dict1["a"], equals: 1)

        guard case let .toolCall(id2, name2, args2) = events[1] else {
            Issue.record("Expected second event to be .toolCall")
            return
        }

        #expect(id2 == "call_2")
        #expect(name2 == "SecondTool")

        guard case let .object(dict2) = args2 else {
            Issue.record("Expected second tool call args to decode as an object")
            return
        }
        expectInteger(dict2["b"], equals: 2)
    }
}
