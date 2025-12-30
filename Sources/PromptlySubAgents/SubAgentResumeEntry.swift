import Foundation
import PromptlyKit

struct SubAgentResumeEntry: Sendable {
    let resumeId: String
    let agentName: String
    let historyEntries: [PromptHistoryEntry]
    let resumeToken: String?
    let createdAt: Date
}
