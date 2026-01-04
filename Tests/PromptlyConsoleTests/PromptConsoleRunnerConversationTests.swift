import PromptlyKit
import PromptlyKitUtils
@testable import PromptlyConsole
import Testing

struct PromptConsoleRunnerConversationTests {
    @Test
    func preservesToolOutputsInConversationForFollowUp() {
        let conversation = [
            PromptMessage(role: .user, content: .text("Start"))
        ]

        let toolArguments = JSONValue.object([
            "task": .string("Collect details")
        ])
        let toolCall = PromptToolCall(
            id: "call_1",
            name: "SubAgent-example",
            arguments: toolArguments
        )
        let toolOutput = JSONValue.object([
            "needsMoreInformation": .bool(true),
            "resumeId": .string("resume-123")
        ])

        let entries: [PromptMessage] = [
            PromptMessage(role: .assistant, content: .text("Let me ask the sub agent.")),
            PromptMessage(role: .assistant, content: .empty, toolCalls: [toolCall]),
            PromptMessage(role: .tool, content: .json(toolOutput), toolCallId: "call_1")
        ]

        let result = PromptRunResult(conversationEntries: entries)
        let updatedConversation = PromptConsoleRunner.appendConversationEntries(
            conversation,
            from: result
        )

        #expect(updatedConversation.count == conversation.count + entries.count)

        guard let toolMessage = updatedConversation.first(where: { $0.role == .tool }) else {
            Issue.record("Expected a tool output message in the conversation.")
            return
        }

        guard case let .json(outputValue) = toolMessage.content else {
            Issue.record("Expected tool output content to be JSON.")
            return
        }

        guard case let .object(outputObject) = outputValue else {
            Issue.record("Expected tool output JSON object.")
            return
        }

        guard case let .string(resumeIdentifier) = outputObject["resumeId"] else {
            Issue.record("Expected resumeId to be present in tool output.")
            return
        }

        #expect(resumeIdentifier == "resume-123")
    }
}
