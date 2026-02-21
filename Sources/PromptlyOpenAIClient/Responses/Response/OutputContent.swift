import Foundation

public struct OutputContent: Decodable, Sendable {
    public let type: String
    public let text: String?
}
