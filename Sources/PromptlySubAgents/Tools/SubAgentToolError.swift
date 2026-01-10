import Foundation

enum SubAgentToolError: Error, LocalizedError {
    case invalidResumeId(resumeId: String)
    case resumeAgentMismatch(resumeId: String, expectedAgentName: String, actualAgentName: String)
    case missingResponsesResumeToken(agentName: String, resumeId: String)
    case missingForkedTranscript
    case emptyForkedTranscript
    case emptyForkedTranscriptRole(index: Int)
    case invalidForkedTranscriptRole(index: Int, role: String)
    case emptyForkedTranscriptContent(index: Int)
    case forkedTranscriptTooLarge(maximumMessageCount: Int, maximumCharacterCount: Int)

    var errorDescription: String? {
        switch self {
        case let .invalidResumeId(resumeId):
            return "Resume identifier \(resumeId) was not found."
        case let .resumeAgentMismatch(resumeId, expectedAgentName, actualAgentName):
            return "Resume identifier \(resumeId) belongs to \(actualAgentName), not \(expectedAgentName)."
        case let .missingResponsesResumeToken(agentName, resumeId):
            return "Sub agent \(agentName) cannot resume because resume identifier \(resumeId) is missing a responses token."
        case .missingForkedTranscript:
            return "Forked transcript is required when handoffStrategy is forkedContext."
        case .emptyForkedTranscript:
            return "Forked transcript must include at least one entry."
        case let .emptyForkedTranscriptRole(index):
            return "Forked transcript entry \(index + 1) is missing a role."
        case let .invalidForkedTranscriptRole(index, role):
            return "Forked transcript entry \(index + 1) has unsupported role \(role)."
        case let .emptyForkedTranscriptContent(index):
            return "Forked transcript entry \(index + 1) is missing content."
        case let .forkedTranscriptTooLarge(maximumMessageCount, maximumCharacterCount):
            return "Forked transcript exceeds limits (\(maximumMessageCount) messages, \(maximumCharacterCount) characters)."
        }
    }
}
