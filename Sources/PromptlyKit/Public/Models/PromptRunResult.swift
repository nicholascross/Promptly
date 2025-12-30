public struct PromptRunResult: Sendable {
    public let promptTranscript: [PromptTranscriptEntry]
    public let historyEntries: [PromptHistoryEntry]
    public let resumeToken: String?

    public init(
        promptTranscript: [PromptTranscriptEntry],
        historyEntries: [PromptHistoryEntry] = [],
        resumeToken: String? = nil
    ) {
        self.promptTranscript = promptTranscript
        self.historyEntries = historyEntries
        self.resumeToken = resumeToken
    }
}
