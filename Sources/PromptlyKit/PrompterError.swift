import Foundation

public enum PrompterError: Error {
    case tokenNotSpecified
    case invalidConfiguration
    case missingConfiguration
    case invalidResponse(statusCode: Int)
    case apiError(String)
}
