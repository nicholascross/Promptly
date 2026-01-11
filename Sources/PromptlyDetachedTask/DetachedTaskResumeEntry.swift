import Foundation
import PromptlyKit

public struct DetachedTaskResumeEntry: Sendable {
    public let resumeId: String
    public let agentName: String
    public let conversationEntries: [PromptMessage]
    public let resumeToken: String?
    public let forkedTranscript: [DetachedTaskForkedTranscriptEntry]?
    public let createdAt: Date

    public init(
        resumeId: String,
        agentName: String,
        conversationEntries: [PromptMessage],
        resumeToken: String?,
        forkedTranscript: [DetachedTaskForkedTranscriptEntry]?,
        createdAt: Date
    ) {
        self.resumeId = resumeId
        self.agentName = agentName
        self.conversationEntries = conversationEntries
        self.resumeToken = resumeToken
        self.forkedTranscript = forkedTranscript
        self.createdAt = createdAt
    }
}

public protocol DetachedTaskResumeStoring: Sendable {
    func entry(for resumeId: String) async -> DetachedTaskResumeEntry?

    func storeResumeEntry(
        resumeId: String?,
        agentName: String,
        conversationEntries: [PromptMessage],
        resumeToken: String?,
        forkedTranscript: [DetachedTaskForkedTranscriptEntry]?
    ) async -> DetachedTaskResumeEntry

    func removeResumeEntry(for resumeId: String) async
}
