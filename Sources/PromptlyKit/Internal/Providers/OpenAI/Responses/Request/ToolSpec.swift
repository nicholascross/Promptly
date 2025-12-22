import Foundation
import PromptlyKitUtils

struct ToolSpec: Encodable {
    let type = "function"
    let name: String
    let description: String
    let parameters: JSONSchema
}
