import PromptlyKit

struct DetachedTaskReturnProcessingContext: Sendable {
    let request: DetachedTaskRequest
    let handoffMessages: [PromptMessage]
    let conversationEntries: [PromptMessage]
    let payload: DetachedTaskReturnPayload
    let didUseFallback: Bool
}

struct DetachedTaskFollowUpContext: Sendable {
    let request: DetachedTaskRequest
    let userMessage: PromptMessage
    let handoffMessages: [PromptMessage]
    let resumePrefixMessages: [PromptMessage]
    let resumeEntry: DetachedTaskResumeEntry?
    let conversationEntries: [PromptMessage]
}

public struct DetachedTaskResumePrefixContext: Sendable {
    public let request: DetachedTaskRequest
    public let resumeEntry: DetachedTaskResumeEntry?

    public init(
        request: DetachedTaskRequest,
        resumeEntry: DetachedTaskResumeEntry?
    ) {
        self.request = request
        self.resumeEntry = resumeEntry
    }
}

struct DetachedTaskHandoffPlan: Sendable {
    let handoffMessages: [PromptMessage]
    let resumePrefixProvider: @Sendable (DetachedTaskResumePrefixContext) throws -> [PromptMessage]
    let followUpMessageProvider: @Sendable (DetachedTaskFollowUpContext) -> [PromptMessage]
    let returnPayloadProcessor: @Sendable (DetachedTaskReturnProcessingContext) -> DetachedTaskReturnPayload
}
