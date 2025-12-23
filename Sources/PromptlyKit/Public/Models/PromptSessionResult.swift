public struct PromptSessionResult: Sendable {
    public let finalAssistantText: String?
    public let promptTranscript: [PromptTranscriptEntry]
}
