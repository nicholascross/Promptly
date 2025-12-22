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
    var promptMessages: [PromptMessage] {
        map { message in
            switch message {
            case let .user(content):
                return PromptMessage(role: .user, content: .text(content))
            case let .system(content):
                return PromptMessage(role: .system, content: .text(content))
            case let .assistant(content):
                return PromptMessage(role: .assistant, content: .text(content))
            }
        }
    }
}
