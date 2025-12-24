import Foundation

enum SubAgentToolError: Error, LocalizedError {
    case executionUnavailable(agentName: String)

    var errorDescription: String? {
        switch self {
        case let .executionUnavailable(agentName):
            return "Sub agent execution is not available yet for \(agentName)."
        }
    }
}
