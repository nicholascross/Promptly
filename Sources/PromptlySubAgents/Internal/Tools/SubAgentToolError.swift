import Foundation

enum SubAgentToolError: Error, LocalizedError {
    case missingForkedTranscript

    var errorDescription: String? {
        switch self {
        case .missingForkedTranscript:
            return "Forked transcript is required when handoffStrategy is forkedContext."
        }
    }
}
