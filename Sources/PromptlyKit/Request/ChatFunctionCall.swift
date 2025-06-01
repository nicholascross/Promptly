import Foundation

public struct ChatFunctionCall: Codable {
    public let id: String
    public let function: ChatFunction
    public let type: String
}
