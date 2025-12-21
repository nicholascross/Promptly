import ArgumentParser
import PromptlyKit

enum Message: ExpressibleByArgument {
    case user(String)
    case system(String)
    case assistant(String)

    init?(argument: String) {
        if argument.hasPrefix("user:") {
            self = .user(argument.dropFirst(5).description)
        } else if argument.hasPrefix("system:") {
            self = .system(argument.dropFirst(7).description)
        } else if argument.hasPrefix("assistant:") {
            self = .assistant(argument.dropFirst(10).description)
        } else {
            return nil
        }
    }
}

extension [Message] {
    var chatMessages: [ChatMessage] {
        map { message in
            switch message {
            case let .user(content):
                return ChatMessage(role: .user, content: .text(content))
            case let .system(content):
                return ChatMessage(role: .system, content: .text(content))
            case let .assistant(content):
                return ChatMessage(role: .assistant, content: .text(content))
            }
        }
    }
}
