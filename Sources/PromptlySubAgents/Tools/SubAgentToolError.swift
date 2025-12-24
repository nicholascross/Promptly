import Foundation

enum SubAgentToolError: Error, LocalizedError {
    case missingReturnPayload(agentName: String)

    var errorDescription: String? {
        switch self {
        case let .missingReturnPayload(agentName):
            return "Sub agent \(agentName) did not return a payload."
        }
    }
}
