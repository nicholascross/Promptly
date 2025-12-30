public struct PromptRunResult: Sendable {
    public let conversationEntries: [PromptMessage]
    public let resumeToken: String?

    public init(
        conversationEntries: [PromptMessage] = [],
        resumeToken: String? = nil
    ) {
        self.conversationEntries = conversationEntries
        self.resumeToken = resumeToken
    }
}
