import Foundation
import PromptlyKitUtils

struct ChatFunction: Codable, Sendable {
    let name: String
    let arguments: String

    init(name: String, arguments: JSONValue) throws {
        let data = try JSONEncoder().encode(arguments)
        self.arguments = String(data: data, encoding: .utf8) ?? ""
        self.name = name
    }

    init(name: String, argumentsText: String) {
        self.name = name
        self.arguments = argumentsText
    }
}
