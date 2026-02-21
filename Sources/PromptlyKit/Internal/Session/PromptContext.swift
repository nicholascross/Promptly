import Foundation
import PromptlyOpenAIClient

enum PromptContext: Sendable {
    case responses(previousResponseIdentifier: String)
    case chatCompletions(messages: [ChatMessage])
}
