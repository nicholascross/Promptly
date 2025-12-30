public enum PromptRunContext: Sendable {
    case messages([PromptMessage])
    case resume(resumeToken: String, requestMessages: [PromptMessage])
}
