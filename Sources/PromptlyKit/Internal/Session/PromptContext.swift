import Foundation

enum PromptContext: Sendable {
    case responses(previousResponseIdentifier: String)
    case chatCompletions(messages: [ChatMessage])
}
