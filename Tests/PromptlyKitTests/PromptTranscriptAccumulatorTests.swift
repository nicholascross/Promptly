import Foundation
@testable import PromptlyKit
import Testing

struct PromptTranscriptAccumulatorTests {
    @Test
    func groupsAssistantDeltasIntoSingleMessage() {
        var accumulator = PromptTranscriptAccumulator()
        accumulator.handle(.assistantTextDelta("Hel"))
        accumulator.handle(.assistantTextDelta("lo"))

        let transcript = accumulator.finish()
        #expect(transcript.count == 1)

        guard case let .assistant(message) = transcript.first else {
            Issue.record("Expected assistant transcript entry")
            return
        }
        #expect(message == "Hello")
    }

    @Test
    func flushesAssistantBeforeToolCallAndRecordsToolCallWithOutput() {
        var accumulator = PromptTranscriptAccumulator()

        accumulator.handle(.assistantTextDelta("Checking..."))
        accumulator.handle(.toolCallRequested(id: "call_1", name: "Echo", arguments: .object(["a": .integer(1)])))
        accumulator.handle(.toolCallCompleted(id: "call_1", name: "Echo", output: .string("ok")))
        accumulator.handle(.assistantTextDelta("Done."))

        let transcript = accumulator.finish()
        #expect(transcript.count == 3)

        guard case let .assistant(message1) = transcript[0] else {
            Issue.record("Expected assistant message before tool call")
            return
        }
        #expect(message1 == "Checking...")

        guard case let .toolCall(id, name, args, output) = transcript[1] else {
            Issue.record("Expected tool call entry")
            return
        }
        #expect(id == "call_1")
        #expect(name == "Echo")

        guard case let .object(dict)? = args else {
            Issue.record("Expected tool call args to be object")
            return
        }
        guard case let .integer(value)? = dict["a"] else {
            Issue.record("Expected tool call args to include integer a")
            return
        }
        #expect(value == 1)

        guard case let .string(text)? = output else {
            Issue.record("Expected tool call output to be string")
            return
        }
        #expect(text == "ok")

        guard case let .assistant(message2) = transcript[2] else {
            Issue.record("Expected assistant message after tool call")
            return
        }
        #expect(message2 == "Done.")
    }

    @Test
    func tombstonesToolOutputWhenConfigured() {
        var accumulator = PromptTranscriptAccumulator(
            configuration: .init(toolOutputPolicy: .tombstone)
        )

        accumulator.handle(.toolCallRequested(id: "call_1", name: "Echo", arguments: .object([:])))
        accumulator.handle(.toolCallCompleted(id: "call_1", name: "Echo", output: .string("sensitive")))

        let transcript = accumulator.finish()
        #expect(transcript.count == 1)

        guard case let .toolCall(_, _, _, output) = transcript[0] else {
            Issue.record("Expected tool call entry")
            return
        }

        guard case let .string(text)? = output else {
            Issue.record("Expected tombstoned tool output")
            return
        }
        #expect(text == "[tool output omitted]")
    }
}
