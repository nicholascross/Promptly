import Foundation
import PromptlyKitUtils

struct SubAgentToolRequest: Decodable, Sendable {
    let task: String
    let contextPack: JSONValue?
    let goals: [String]?
    let constraints: [String]?
    let resumeId: String?
    let handoff: SubAgentHandoff

    private enum CodingKeys: String, CodingKey {
        case task
        case contextPack
        case goals
        case constraints
        case resumeId
        case handoffStrategy
        case forkedTranscript
    }

    private enum HandoffStrategyKey: String, Decodable {
        case contextPack
        case forkedContext
    }

    init(
        task: String,
        contextPack: JSONValue?,
        goals: [String]?,
        constraints: [String]?,
        resumeId: String?,
        handoff: SubAgentHandoff
    ) {
        self.task = task
        self.contextPack = contextPack
        self.goals = goals
        self.constraints = constraints
        self.resumeId = resumeId
        self.handoff = handoff
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        task = try container.decode(String.self, forKey: .task)
        contextPack = try container.decodeIfPresent(JSONValue.self, forKey: .contextPack)
        goals = try container.decodeIfPresent([String].self, forKey: .goals)
        constraints = try container.decodeIfPresent([String].self, forKey: .constraints)
        resumeId = try container.decodeIfPresent(String.self, forKey: .resumeId)

        let strategy = try container.decode(HandoffStrategyKey.self, forKey: .handoffStrategy)
        switch strategy {
        case .contextPack:
            handoff = .contextPack
        case .forkedContext:
            if let forkedTranscript = try container.decodeIfPresent(
                [SubAgentForkedTranscriptEntry].self,
                forKey: .forkedTranscript
            ) {
                handoff = .forkedContext(forkedTranscript)
            } else if Self.hasValidResumeIdentifier(resumeId) {
                handoff = .forkedContext([])
            } else {
                throw SubAgentToolError.missingForkedTranscript
            }
        }
    }

    private static func hasValidResumeIdentifier(_ resumeIdentifier: String?) -> Bool {
        guard let resumeIdentifier else {
            return false
        }
        let trimmedIdentifier = resumeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            return false
        }
        return UUID(uuidString: trimmedIdentifier) != nil
    }
}
