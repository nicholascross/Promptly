import Foundation

public enum PromptError: Error {
    case tokenNotSpecified
    case invalidConfiguration
    case resumeNotSupported
    case missingConfiguration
    case invalidResponse(statusCode: Int)
    case apiError(String)
}
