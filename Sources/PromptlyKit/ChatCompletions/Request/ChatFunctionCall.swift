import Foundation

public struct ChatFunctionCall: Codable, Sendable {
    public let id: String
    public let function: ChatFunction
    public let type: String
}
