import Foundation

public enum PromptError: Error {
    case tokenNotSpecified
    case invalidConfiguration
    case invalidRunContext(String)
    case resumeNotSupported
    case missingConfiguration
    case invalidResponse(statusCode: Int)
    case apiError(String)
}
