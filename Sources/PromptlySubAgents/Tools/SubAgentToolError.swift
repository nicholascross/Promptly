import Foundation

enum SubAgentToolError: Error, LocalizedError {
    case missingReturnPayload(agentName: String)
    case invalidResumeId(resumeId: String)
    case resumeAgentMismatch(resumeId: String, expectedAgentName: String, actualAgentName: String)
    case missingResponsesResumeToken(agentName: String, resumeId: String)

    var errorDescription: String? {
        switch self {
        case let .missingReturnPayload(agentName):
            return "Sub agent \(agentName) did not return a payload."
        case let .invalidResumeId(resumeId):
            return "Resume identifier \(resumeId) was not found."
        case let .resumeAgentMismatch(resumeId, expectedAgentName, actualAgentName):
            return "Resume identifier \(resumeId) belongs to \(actualAgentName), not \(expectedAgentName)."
        case let .missingResponsesResumeToken(agentName, resumeId):
            return "Sub agent \(agentName) cannot resume because resume identifier \(resumeId) is missing a responses token."
        }
    }
}
