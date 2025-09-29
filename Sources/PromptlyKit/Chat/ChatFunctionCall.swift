import Foundation

public struct ChatFunctionCall: Codable, Sendable {
    public let id: String
    public let function: ChatFunction
    public let type: String

    public init(id: String, function: ChatFunction, type: String) {
        self.id = id
        self.function = function
        self.type = type
    }
}
