import Foundation

public struct PromptMessage: Codable, Sendable {
    public let role: PromptRole
    public let content: PromptContent

    public init(role: PromptRole, content: PromptContent) {
        self.role = role
        self.content = content
    }
}
