import Foundation
import PromptlyKit

public actor SubAgentSessionState {
    private var resumeEntries: [String: SubAgentResumeEntry] = [:]
    private let dateProvider: @Sendable () -> Date

    public init(dateProvider: @Sendable @escaping () -> Date = Date.init) {
        self.dateProvider = dateProvider
    }

    func entry(for resumeId: String) -> SubAgentResumeEntry? {
        resumeEntries[resumeId]
    }

    func storeResumeEntry(
        resumeId: String?,
        agentName: String,
        historyEntries: [PromptHistoryEntry],
        resumeToken: String?
    ) -> SubAgentResumeEntry {
        if let resumeId, let existing = resumeEntries[resumeId] {
            let updated = SubAgentResumeEntry(
                resumeId: resumeId,
                agentName: agentName,
                historyEntries: historyEntries,
                resumeToken: resumeToken,
                createdAt: existing.createdAt
            )
            resumeEntries[resumeId] = updated
            return updated
        }

        let newResumeId = resumeId ?? UUID().uuidString.lowercased()
        let entry = SubAgentResumeEntry(
            resumeId: newResumeId,
            agentName: agentName,
            historyEntries: historyEntries,
            resumeToken: resumeToken,
            createdAt: dateProvider()
        )
        resumeEntries[newResumeId] = entry
        return entry
    }
}
