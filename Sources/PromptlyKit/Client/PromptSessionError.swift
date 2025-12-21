import Foundation

public enum PromptSessionError: Error, LocalizedError {
    case missingInput
    case cannedPromptNotFound(URL)

    public var errorDescription: String? {
        switch self {
        case .missingInput:
            return "No input provided. Usage: promptly prompt [options] <context> or --message or piped stdin"
        case let .cannedPromptNotFound(url):
            return "Canned prompt \(url) not found."
        }
    }
}
