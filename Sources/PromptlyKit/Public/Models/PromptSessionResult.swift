public struct PromptSessionResult: Sendable {
    public let promptTranscript: [PromptTranscriptEntry]
    public let conversationEntries: [PromptConversationEntry]
    public let resumeToken: String?

    public init(
        promptTranscript: [PromptTranscriptEntry],
        conversationEntries: [PromptConversationEntry] = [],
        resumeToken: String? = nil
    ) {
        self.promptTranscript = promptTranscript
        self.conversationEntries = conversationEntries
        self.resumeToken = resumeToken
    }
}
