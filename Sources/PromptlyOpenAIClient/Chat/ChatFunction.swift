import Foundation
import PromptlyKitUtils

public struct ChatFunction: Codable, Sendable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: JSONValue) throws {
        let data = try JSONEncoder().encode(arguments)
        self.arguments = String(data: data, encoding: .utf8) ?? ""
        self.name = name
    }

    public init(name: String, argumentsText: String) {
        self.name = name
        self.arguments = argumentsText
    }
}
