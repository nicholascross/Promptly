import Foundation
import PromptlyKitUtils

public enum PromptContent: Codable, Sendable {
    case text(String)
    case json(JSONValue)
    case empty
}
