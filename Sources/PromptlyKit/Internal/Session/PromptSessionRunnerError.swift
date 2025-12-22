import Foundation

enum PromptSessionRunnerError: Error, LocalizedError, Sendable {
    case toolIterationLimitExceeded(limit: Int)
    case missingContinuationToken

    var errorDescription: String? {
        switch self {
        case let .toolIterationLimitExceeded(limit):
            return "Tool iteration limit exceeded (\(limit))."
        case .missingContinuationToken:
            return "Missing continuation token for tool call continuation."
        }
    }
}
