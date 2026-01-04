import Foundation

enum PromptRunExecutorError: Error, LocalizedError, Sendable {
    case toolIterationLimitExceeded(limit: Int)
    case missingContinuationContext
    case missingToolCallIdentifier
    case missingToolOutputIdentifier

    var errorDescription: String? {
        switch self {
        case let .toolIterationLimitExceeded(limit):
            return "Tool iteration limit exceeded (\(limit))."
        case .missingContinuationContext:
            return "Missing continuation context for tool call continuation."
        case .missingToolCallIdentifier:
            return "Tool call identifier is missing."
        case .missingToolOutputIdentifier:
            return "Tool call identifier is missing for tool output."
        }
    }
}
