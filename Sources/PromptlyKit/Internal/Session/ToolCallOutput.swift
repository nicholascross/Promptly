import Foundation
import PromptlyKitUtils

struct ToolCallOutput: Sendable {
    public let id: String
    public let output: JSONValue

    public init(id: String, output: JSONValue) {
        self.id = id
        self.output = output
    }
}
