public struct PromptRunResult: Sendable {
    public let promptTranscript: [PromptTranscriptEntry]
    public let conversationEntries: [PromptMessage]
    public let resumeToken: String?

    public init(
        promptTranscript: [PromptTranscriptEntry],
        conversationEntries: [PromptMessage] = [],
        resumeToken: String? = nil
    ) {
        self.promptTranscript = promptTranscript
        self.conversationEntries = conversationEntries
        self.resumeToken = resumeToken
    }
}
