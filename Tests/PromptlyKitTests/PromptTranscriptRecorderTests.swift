import Foundation
@testable import PromptlyKit
import Testing

struct PromptTranscriptRecorderTests {
    @Test
    func groupsAssistantDeltasIntoSingleMessage() async {
        let recorder = PromptTranscriptRecorder()
        await recorder.handle(.assistantTextDelta("Hel"))
        await recorder.handle(.assistantTextDelta("lo"))

        let transcript = await recorder.finish()
        #expect(transcript.count == 1)

        guard case let .assistant(message) = transcript.first else {
            Issue.record("Expected assistant transcript entry")
            return
        }
        #expect(message == "Hello")
    }

    @Test
    func flushesAssistantBeforeToolCallAndRecordsToolCallWithOutput() async {
        let recorder = PromptTranscriptRecorder(
            configuration: .init(toolOutputPolicy: .include)
        )

        await recorder.handle(.assistantTextDelta("Checking..."))
        await recorder.handle(.toolCallRequested(id: "call_1", name: "Echo", arguments: .object(["a": .integer(1)])))
        await recorder.handle(.toolCallCompleted(id: "call_1", name: "Echo", output: .string("ok")))
        await recorder.handle(.assistantTextDelta("Done."))

        let transcript = await recorder.finish()
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
    func tombstonesToolOutputWhenConfigured() async {
        let recorder = PromptTranscriptRecorder(
            configuration: .init(toolOutputPolicy: .tombstone)
        )

        await recorder.handle(.toolCallRequested(id: "call_1", name: "Echo", arguments: .object([:])))
        await recorder.handle(.toolCallCompleted(id: "call_1", name: "Echo", output: .string("sensitive")))

        let transcript = await recorder.finish()
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
