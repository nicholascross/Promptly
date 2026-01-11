import Foundation

public enum DetachedTaskRunnerError: Error, LocalizedError, Sendable {
    case invalidResumeIdentifier(resumeIdentifier: String)
    case resumeAgentMismatch(
        resumeIdentifier: String,
        expectedAgentName: String,
        actualAgentName: String
    )
    case missingResponsesResumeToken(
        agentName: String,
        resumeIdentifier: String
    )
    case missingResumeStore(resumeIdentifier: String)

    public var errorDescription: String? {
        switch self {
        case let .invalidResumeIdentifier(resumeIdentifier):
            return "Resume identifier \(resumeIdentifier) was not found."
        case let .resumeAgentMismatch(resumeIdentifier, expectedAgentName, actualAgentName):
            return "Resume identifier \(resumeIdentifier) belongs to \(actualAgentName), not \(expectedAgentName)."
        case let .missingResponsesResumeToken(agentName, resumeIdentifier):
            return "Detached task \(agentName) cannot resume because resume identifier \(resumeIdentifier) is missing a responses token."
        case let .missingResumeStore(resumeIdentifier):
            return "Resume identifier \(resumeIdentifier) was provided without a resume store."
        }
    }
}
