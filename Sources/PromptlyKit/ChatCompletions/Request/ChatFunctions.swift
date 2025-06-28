import Foundation

public struct ChatFunction: Codable {
    public let name: String
    public let arguments: String

    public init(name: String, arguments: JSONValue) throws {
        self.name = name
        let data = try JSONEncoder().encode(arguments)
        self.arguments = String(data: data, encoding: .utf8) ?? ""
    }
}
