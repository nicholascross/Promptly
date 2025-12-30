import Foundation

enum PromptSessionRunnerError: Error, LocalizedError, Sendable {
    case toolIterationLimitExceeded(limit: Int)
    case missingContinuationContext

    var errorDescription: String? {
        switch self {
        case let .toolIterationLimitExceeded(limit):
            return "Tool iteration limit exceeded (\(limit))."
        case .missingContinuationContext:
            return "Missing continuation context for tool call continuation."
        }
    }
}
