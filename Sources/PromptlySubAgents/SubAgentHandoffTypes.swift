import PromptlyKit
import PromptlyKitUtils

enum SubAgentHandoff: Sendable {
    case contextPack
    case forkedContext([SubAgentForkedTranscriptEntry])
}

struct SubAgentForkedTranscriptEntry: Decodable, Sendable {
    let role: String
    let content: String
}

struct SubAgentReturnProcessingContext: Sendable {
    let request: SubAgentToolRequest
    let handoffMessages: [PromptMessage]
    let conversationEntries: [PromptMessage]
    let payload: JSONValue
    let didUseFallback: Bool
}

struct SubAgentFollowUpContext: Sendable {
    let request: SubAgentToolRequest
    let userMessage: PromptMessage
    let handoffMessages: [PromptMessage]
    let resumePrefixMessages: [PromptMessage]
    let resumeEntry: SubAgentResumeEntry?
    let conversationEntries: [PromptMessage]
}

struct SubAgentResumePrefixContext: Sendable {
    let request: SubAgentToolRequest
    let resumeEntry: SubAgentResumeEntry?
}

struct SubAgentHandoffPlan: Sendable {
    let handoffMessages: [PromptMessage]
    let resumePrefixProvider: @Sendable (SubAgentResumePrefixContext) throws -> [PromptMessage]
    let followUpMessageProvider: @Sendable (SubAgentFollowUpContext) -> [PromptMessage]
    let returnPayloadProcessor: @Sendable (SubAgentReturnProcessingContext) -> JSONValue
}
