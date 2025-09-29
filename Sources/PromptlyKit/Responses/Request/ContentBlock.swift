import Foundation

public struct ContentBlock: Codable, Sendable {
    public let type: String
    public let text: String?
    public let id: String?
    public let output: String?
    public let isError: Bool?
    public let name: String?
    public let arguments: String?
    enum CodingKeys: String, CodingKey {
        case type, text, id, output, name, arguments
        case isError = "is_error"
    }

    public init(
        type: String,
        text: String? = nil,
        id: String? = nil,
        output: String? = nil,
        isError: Bool? = nil,
        name: String? = nil,
        arguments: String? = nil
    ) {
        self.type = type
        self.text = text
        self.id = id
        self.output = output
        self.isError = isError
        self.name = name
        self.arguments = arguments
    }
}
