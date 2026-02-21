import Foundation

public struct APIErrorEnvelope: Decodable, Sendable {
    public struct APIError: Decodable, Sendable {
        public let message: String
    }

    public let error: APIError
}
