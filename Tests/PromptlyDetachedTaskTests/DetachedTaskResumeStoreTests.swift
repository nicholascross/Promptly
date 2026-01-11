import Foundation
import PromptlyKit
@testable import PromptlyDetachedTask
import Testing

struct DetachedTaskResumeStoreTests {
    @Test
    func storeResumeEntryDeduplicatesMatchingPrefix() async {
        let store = DetachedTaskResumeStore(
            dateProvider: { Date(timeIntervalSince1970: 0) }
        )
        let firstEntries = [
            PromptMessage(role: .user, content: .text("First")),
            PromptMessage(role: .assistant, content: .text("Second"))
        ]
        _ = await store.storeResumeEntry(
            resumeId: "resume-id",
            agentName: "Test Agent",
            conversationEntries: firstEntries,
            resumeToken: nil,
            forkedTranscript: nil
        )

        let secondEntries = firstEntries + [
            PromptMessage(role: .assistant, content: .text("Third"))
        ]
        let updated = await store.storeResumeEntry(
            resumeId: "resume-id",
            agentName: "Test Agent",
            conversationEntries: secondEntries,
            resumeToken: nil,
            forkedTranscript: nil
        )

        #expect(updated.conversationEntries.count == 3)
        guard case let .text(text) = updated.conversationEntries.last?.content else {
            Issue.record("Expected a text message at the end of the transcript.")
            return
        }
        #expect(text == "Third")
    }
}
