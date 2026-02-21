import Foundation
import PromptlyKit
import PromptlyKitUtils

public actor DetachedTaskResumeStore: DetachedTaskResumeStoring {
    private var resumeEntries: [String: DetachedTaskResumeEntry] = [:]
    private let dateProvider: @Sendable () -> Date

    public init(
        dateProvider: @Sendable @escaping () -> Date = Date.init
    ) {
        self.dateProvider = dateProvider
    }

    public func entry(for resumeId: String) async -> DetachedTaskResumeEntry? {
        resumeEntries[resumeId]
    }

    public func storeResumeEntry(
        resumeId: String?,
        agentName: String,
        conversationEntries: [PromptMessage],
        resumeToken: String?,
        forkedTranscript: [DetachedTaskForkedTranscriptEntry]?
    ) async -> DetachedTaskResumeEntry {
        if let resumeId, let existing = resumeEntries[resumeId] {
            let mergedEntries = mergeConversationEntries(
                existing: existing.conversationEntries,
                newEntries: conversationEntries
            )
            let updated = DetachedTaskResumeEntry(
                resumeId: resumeId,
                agentName: agentName,
                conversationEntries: mergedEntries,
                resumeToken: resumeToken,
                forkedTranscript: forkedTranscript ?? existing.forkedTranscript,
                createdAt: existing.createdAt
            )
            resumeEntries[resumeId] = updated
            return updated
        }

        let newResumeId = resumeId ?? UUID().uuidString.lowercased()
        let entry = DetachedTaskResumeEntry(
            resumeId: newResumeId,
            agentName: agentName,
            conversationEntries: conversationEntries,
            resumeToken: resumeToken,
            forkedTranscript: forkedTranscript,
            createdAt: dateProvider()
        )
        resumeEntries[newResumeId] = entry
        return entry
    }

    public func removeResumeEntry(for resumeId: String) async {
        resumeEntries.removeValue(forKey: resumeId)
    }

    private func mergeConversationEntries(
        existing: [PromptMessage],
        newEntries: [PromptMessage]
    ) -> [PromptMessage] {
        let prefixCount = matchingPrefixCount(
            existing: existing,
            newEntries: newEntries
        )
        let remainder = newEntries.dropFirst(prefixCount)
        return existing + remainder
    }

    private func matchingPrefixCount(
        existing: [PromptMessage],
        newEntries: [PromptMessage]
    ) -> Int {
        let maximumMatchCount = min(existing.count, newEntries.count)
        var matchCount = 0
        while matchCount < maximumMatchCount {
            if !messagesMatch(existing[matchCount], newEntries[matchCount]) {
                break
            }
            matchCount += 1
        }
        return matchCount
    }

    private func messagesMatch(
        _ left: PromptMessage,
        _ right: PromptMessage
    ) -> Bool {
        guard left.role == right.role else { return false }
        guard contentKey(for: left.content) == contentKey(for: right.content) else {
            return false
        }
        return toolCallIdentifier(for: left) == toolCallIdentifier(for: right)
    }

    private func contentKey(for content: PromptContent) -> String {
        switch content {
        case let .text(text):
            return text
        case let .json(value):
            return encodedJSONText(from: value) ?? value.description
        case .empty:
            return ""
        }
    }

    private func toolCallIdentifier(for message: PromptMessage) -> String? {
        if let toolCallId = message.toolCallId {
            return toolCallId
        }
        guard let toolCalls = message.toolCalls, !toolCalls.isEmpty else {
            return nil
        }
        let identifiers = toolCalls.compactMap { $0.id }
        if identifiers.isEmpty {
            return nil
        }
        return identifiers.joined(separator: ",")
    }

    private func encodedJSONText(from value: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
