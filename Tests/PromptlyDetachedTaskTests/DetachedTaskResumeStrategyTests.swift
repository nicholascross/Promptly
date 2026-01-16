import Foundation
import PromptlyKit
@testable import PromptlyDetachedTask
import Testing

struct DetachedTaskResumeStrategyTests {
    @Test
    func chatCompletionsResumePrefixMessagesRequiresResumeEntry() throws {
        let strategy = ChatCompletionsDetachedTaskResumeStrategy()
        let request = DetachedTaskRequest(
            task: "Test",
            goals: nil,
            constraints: nil,
            contextPack: nil,
            handoffStrategy: .contextPack,
            forkedTranscript: nil,
            resumeId: nil
        )
        do {
            let messages = try strategy.resumePrefixMessages(
                request: request,
                resumeEntry: nil,
                resumePrefixProvider: { _ in
                    throw ProviderCalledError()
                }
            )
            #expect(messages.isEmpty)
        } catch is ProviderCalledError {
            Issue.record("Resume prefix provider should not be called.")
        }
    }

    @Test
    func chatCompletionsInitialContextReplaysTranscript() throws {
        let strategy = ChatCompletionsDetachedTaskResumeStrategy()
        let resumeEntry = DetachedTaskResumeEntry(
            resumeId: "resume-id",
            agentName: "Agent",
            conversationEntries: [
                PromptMessage(role: .assistant, content: .text("Transcript"))
            ],
            resumeToken: nil,
            forkedTranscript: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let handoffMessages = [
            PromptMessage(role: .system, content: .text("Handoff"))
        ]
        let resumePrefixMessages = [
            PromptMessage(role: .system, content: .text("Prefix"))
        ]
        let userMessage = PromptMessage(role: .user, content: .text("User"))

        let context = try strategy.initialContext(
            handoffMessages: handoffMessages,
            resumePrefixMessages: resumePrefixMessages,
            userMessage: userMessage,
            resumeEntry: resumeEntry
        )

        switch context {
        case let .messages(messages):
            #expect(messages.count == 3)
            assertTextMessage(messages[0], role: .system, text: "Prefix")
            assertTextMessage(messages[1], role: .assistant, text: "Transcript")
            assertTextMessage(messages[2], role: .user, text: "User")
        case .resume:
            Issue.record("Expected a messages context for chat completions.")
        }
    }

    @Test
    func chatCompletionsFollowUpContextAppendsReminder() {
        let strategy = ChatCompletionsDetachedTaskResumeStrategy()
        let context = strategy.followUpContext(
            resumeToken: nil,
            chatMessages: [
                PromptMessage(role: .assistant, content: .text("Existing"))
            ],
            reminderMessage: PromptMessage(role: .user, content: .text("Reminder"))
        )

        switch context {
        case let .messages(messages):
            #expect(messages.count == 2)
            assertTextMessage(messages[0], role: .assistant, text: "Existing")
            assertTextMessage(messages[1], role: .user, text: "Reminder")
        case .resume:
            Issue.record("Expected a messages context for chat completions.")
        }
    }

    @Test
    func responsesResumePrefixMessagesSkipsProvider() throws {
        let strategy = ResponsesDetachedTaskResumeStrategy()
        let request = DetachedTaskRequest(
            task: "Test",
            goals: nil,
            constraints: nil,
            contextPack: nil,
            handoffStrategy: .contextPack,
            forkedTranscript: nil,
            resumeId: nil
        )
        let resumeEntry = DetachedTaskResumeEntry(
            resumeId: "resume-id",
            agentName: "Agent",
            conversationEntries: [],
            resumeToken: "resume-token",
            forkedTranscript: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        do {
            let messages = try strategy.resumePrefixMessages(
                request: request,
                resumeEntry: resumeEntry,
                resumePrefixProvider: { _ in
                    throw ProviderCalledError()
                }
            )
            #expect(messages.isEmpty)
        } catch is ProviderCalledError {
            Issue.record("Resume prefix provider should not be called.")
        }
    }

    @Test
    func responsesInitialContextRequiresResumeToken() throws {
        let strategy = ResponsesDetachedTaskResumeStrategy()
        let resumeEntry = DetachedTaskResumeEntry(
            resumeId: "resume-id",
            agentName: "Agent",
            conversationEntries: [],
            resumeToken: nil,
            forkedTranscript: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let userMessage = PromptMessage(role: .user, content: .text("User"))

        do {
            _ = try strategy.initialContext(
                handoffMessages: [],
                resumePrefixMessages: [],
                userMessage: userMessage,
                resumeEntry: resumeEntry
            )
            Issue.record("Expected missing resume token error.")
        } catch let error as DetachedTaskRunnerError {
            switch error {
            case let .missingResponsesResumeToken(agentName, resumeIdentifier):
                #expect(agentName == "Agent")
                #expect(resumeIdentifier == "resume-id")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        }
    }

    @Test
    func responsesInitialContextUsesResumeToken() throws {
        let strategy = ResponsesDetachedTaskResumeStrategy()
        let resumeEntry = DetachedTaskResumeEntry(
            resumeId: "resume-id",
            agentName: "Agent",
            conversationEntries: [],
            resumeToken: "resume-token",
            forkedTranscript: nil,
            createdAt: Date(timeIntervalSince1970: 0)
        )
        let userMessage = PromptMessage(role: .user, content: .text("User"))

        let context = try strategy.initialContext(
            handoffMessages: [],
            resumePrefixMessages: [],
            userMessage: userMessage,
            resumeEntry: resumeEntry
        )

        switch context {
        case let .resume(resumeToken, requestMessages):
            #expect(resumeToken == "resume-token")
            #expect(requestMessages.count == 1)
            assertTextMessage(requestMessages[0], role: .user, text: "User")
        case .messages:
            Issue.record("Expected a resume context for responses.")
        }
    }

    @Test
    func responsesFollowUpContextUsesResumeTokenWhenAvailable() throws {
        let strategy = ResponsesDetachedTaskResumeStrategy()
        let reminderMessage = PromptMessage(role: .user, content: .text("Reminder"))
        let context = strategy.followUpContext(
            resumeToken: "resume-token",
            chatMessages: [],
            reminderMessage: reminderMessage
        )

        switch context {
        case let .resume(resumeToken, requestMessages):
            #expect(resumeToken == "resume-token")
            #expect(requestMessages.count == 1)
            assertTextMessage(requestMessages[0], role: .user, text: "Reminder")
        case .messages:
            Issue.record("Expected a resume context for responses.")
        }
    }
}

private func assertTextMessage(
    _ message: PromptMessage,
    role: PromptRole,
    text: String
) {
    #expect(message.role == role)
    switch message.content {
    case let .text(content):
        #expect(content == text)
    default:
        Issue.record("Expected text content.")
    }
}

private struct ProviderCalledError: Error {}
