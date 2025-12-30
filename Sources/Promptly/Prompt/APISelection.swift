import ArgumentParser
import Foundation
import PromptlyKit

enum APISelection: ExpressibleByArgument {
    case responses
    case chatCompletions

    init?(argument: String) {
        switch argument.lowercased() {
        case "responses", "response":
            self = .responses
        case "chat", "chat_completions", "chat-completions", "chatcompletions":
            self = .chatCompletions
        default:
            return nil
        }
    }

    var configValue: Config.API {
        switch self {
        case .responses:
            return .responses
        case .chatCompletions:
            return .chatCompletions
        }
    }
}
