import Foundation
import PromptlyKit

struct SubAgentResumeEntry: Sendable {
    let resumeId: String
    let agentName: String
    let conversationEntries: [PromptMessage]
    let resumeToken: String?
    let createdAt: Date
}
