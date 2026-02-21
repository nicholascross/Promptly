import Foundation
import PromptlyKitUtils

public struct OpenAIToolDefinition: Sendable {
    public let name: String
    public let description: String
    public let parameters: JSONSchema

    public init(name: String, description: String, parameters: JSONSchema) {
        self.name = name
        self.description = description
        self.parameters = parameters
    }
}
