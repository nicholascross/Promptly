import Foundation

struct ChatFunctionCall: Codable, Sendable {
    let id: String
    let function: ChatFunction
    let type: String

    init(id: String, function: ChatFunction, type: String) {
        self.id = id
        self.function = function
        self.type = type
    }
}
