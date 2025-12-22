import Foundation

struct ContentBlock: Codable, Sendable {
    let type: String
    let text: String?
    let id: String?
    let output: String?
    let isError: Bool?
    let name: String?
    let arguments: String?
    enum CodingKeys: String, CodingKey {
        case type, text, id, output, name, arguments
        case isError = "is_error"
    }

    init(
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
