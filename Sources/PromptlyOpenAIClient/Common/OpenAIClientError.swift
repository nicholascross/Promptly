import Foundation

public enum OpenAIClientError: Error, Sendable {
    case invalidResponse(statusCode: Int)
    case apiError(String)
}
