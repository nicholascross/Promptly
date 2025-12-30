import Foundation
import PromptlyKitUtils

public struct PromptToolCall: Codable, Sendable {
    public let id: String?
    public let name: String
    public let arguments: JSONValue

    public init(id: String?, name: String, arguments: JSONValue) {
        self.id = id
        self.name = name
        self.arguments = arguments
    }
}
