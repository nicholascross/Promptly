import Foundation

public enum PromptContent: Codable, Sendable {
    case text(String)
    case empty
}
