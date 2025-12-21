import ArgumentParser
import PromptlyKit

struct PromptOptions: ParsableArguments {
    @Argument(help: "A context string to pass to the system prompt.")
    var contextArgument: String?

    @Option(
        name: .customShort("c"),
        help: "Override the default configuration path of ~/.config/promptly/config.json."
    )
    var configFile: String = "~/.config/promptly/config.json"

    @Option(
        name: .customLong("tools"),
        help: "Override the default shell command tools config basename (without .json)."
    )
    var tools: String = "tools"

    @Option(
        name: .customLong("include-tools"),
        help: "Include shell-command tools by name. Provide one or more substrings; only matching tools will be loaded."
    )
    var includeTools: [String] = []

    @Option(
        name: .customLong("exclude-tools"),
        help: "Exclude shell-command tools by name. Provide one or more substrings; any matching tools will be omitted."
    )
    var excludeTools: [String] = []

    @Option(name: .customLong("message"), help: "A message to send to the chat.")
    var messages: [Message] = []

    @Option(
        name: [.customLong("canned"), .customShort("p")],
        help: "Use one or more canned prompts as context."
    )
    var cannedContexts: [String] = []

    @Option(
        name: .customLong("model"),
        help:
        """
        The model to use for the chat.
        May be an alias defined in configuration; if not specified, defaults to configuration
        """
    )
    var model: String?

    @Option(
        name: .customLong("api"),
        help: "Select backend API (responses or chat). Overrides configuration."
    )
    var apiSelection: APISelection?
}

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
