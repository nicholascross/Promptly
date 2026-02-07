import Foundation

public enum PromptConsoleError: Error, LocalizedError {
    case missingInput
    case cannedPromptNotFound(URL)
    case missingResumeIdForFollowUp(String)

    public var errorDescription: String? {
        switch self {
        case .missingInput:
            return "No input provided. Usage: promptly prompt [options] <context> or --message or piped stdin"
        case let .cannedPromptNotFound(url):
            return "Canned prompt \(url) not found."
        case let .missingResumeIdForFollowUp(toolName):
            return "Follow up for \(toolName) requires a valid resumeId, but recovery did not produce one."
        }
    }
}
