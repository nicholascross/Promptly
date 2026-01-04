import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct PromptConversationRecorderTests {
    @Test
    func groupsAssistantDeltasIntoSingleMessage() async throws {
        let recorder = PromptConversationRecorder()
        await recorder.handle(.assistantTextDelta("Hel"))
        await recorder.handle(.assistantTextDelta("lo"))

        let entries = try await recorder.finish()
        #expect(entries.count == 1)

        #expect(entries[0].role == .assistant)
        if case let .text(message) = entries[0].content {
            #expect(message == "Hello")
        } else {
            Issue.record("Expected assistant text message entry.")
        }
    }

    @Test
    func flushesAssistantBeforeToolCallAndRecordsToolOutput() async throws {
        let recorder = PromptConversationRecorder()

        await recorder.handle(.assistantTextDelta("Checking..."))
        await recorder.handle(.toolCallRequested(id: "call_1", name: "Echo", arguments: .object(["a": .integer(1)])))
        await recorder.handle(.toolCallCompleted(id: "call_1", name: "Echo", output: .string("ok")))
        await recorder.handle(.assistantTextDelta("Done."))

        let entries = try await recorder.finish()
        #expect(entries.count == 4)

        #expect(entries[0].role == .assistant)
        if case let .text(message1) = entries[0].content {
            #expect(message1 == "Checking...")
        } else {
            Issue.record("Expected assistant message before tool call.")
        }

        #expect(entries[1].role == .assistant)
        guard let toolCalls = entries[1].toolCalls, let toolCall = toolCalls.first else {
            Issue.record("Expected tool call entry.")
            return
        }
        #expect(toolCall.id == "call_1")
        #expect(toolCall.name == "Echo")

        if case let .object(arguments) = toolCall.arguments {
            if case let .integer(value) = arguments["a"] {
                #expect(value == 1)
            } else {
                Issue.record("Expected tool call args to include integer a.")
            }
        } else {
            Issue.record("Expected tool call args to be object.")
        }

        #expect(entries[2].role == .tool)
        #expect(entries[2].toolCallId == "call_1")
        if case let .json(output) = entries[2].content {
            if case let .string(text) = output {
                #expect(text == "ok")
            } else {
                Issue.record("Expected tool output to be string.")
            }
        } else {
            Issue.record("Expected tool output entry.")
        }

        #expect(entries[3].role == .assistant)
        if case let .text(message2) = entries[3].content {
            #expect(message2 == "Done.")
        } else {
            Issue.record("Expected assistant message after tool call.")
        }
    }
}
