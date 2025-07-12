import ArgumentParser
import Foundation
import PromptlyKit

private let fileManager = FileManager()

@main
struct Promptly: AsyncParsableCommand {
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

    @Flag(name: .customLong("setup-token"), help: "Setup a new token.")
    var setupToken: Bool = false

    @Option(name: .customLong("message"), help: "A message to send to the chat.")
    private var messages: [Message] = []

    @Option(name: [.customLong("canned"), .customShort("p")], help: "Use canned prompt as conext.")
    private var cannedContext: String?

    @Option(
        name: .customLong("model"),
        help: "The model to use for the chat. If not specified defaults to configuration"
    )
    private var model: String?

    mutating func run() async throws {
        let configURL = URL(fileURLWithPath: configFile.expandingTilde).standardizedFileURL
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw PrompterError.missingConfiguration
        }

        if setupToken {
            try await Config.setupToken(configURL: configURL)
            return
        }

        let config = try Config.loadConfig(url: configURL)
        var availableTools = try [PromptTool()]
            + (ToolFactory(fileManager: fileManager, toolsFileName: tools).makeTools())
        if !includeTools.isEmpty {
            availableTools = availableTools.filter { tool in
                includeTools.contains { include in tool.name.contains(include) }
            }
        }

        if !excludeTools.isEmpty {
            availableTools = availableTools.filter { tool in
                !excludeTools.contains { filter in tool.name.contains(filter) }
            }
        }
        let prompter = try Prompter(
            config: config,
            modelOverride: model,
            tools: availableTools
        )

        guard messages.isEmpty else {
            let allMessages: [Message]
            if let cannedContext = cannedContext {
                let prompt = try loadCannedPrompt(name: cannedContext)
                allMessages = [.system(prompt)] + messages
            } else {
                allMessages = messages
            }

            try await prompter.runChatStream(messages: allMessages.chatMessages)
            return
        }

        let prompt: String
        let supplementaryContext: String?
        if let cannedContext = cannedContext {
            prompt = try loadCannedPrompt(name: cannedContext)
            supplementaryContext = contextArgument
        } else {
            guard let contextArgument = contextArgument else {
                throw ValidationError("Usage: promptly <context-string>\\n")
            }
            prompt = contextArgument
            supplementaryContext = nil
        }

        try await prompter.runChatStream(
            systemPrompt: prompt,
            supplementarySystemPrompt: supplementaryContext
        )
    }

    private func loadCannedPrompt(name: String) throws -> String {
        let cannedURL = URL(fileURLWithPath: "~/.config/promptly/canned/\(name).txt".expandingTilde)
            .standardizedFileURL
        guard fileManager.fileExists(atPath: cannedURL.path) else {
            throw ValidationError("Canned prompt \(cannedURL) not found.")
        }
        let data = try Data(contentsOf: cannedURL)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private enum Message: ExpressibleByArgument {
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

private extension [Message] {
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

private extension String {
    var expandingTilde: String {
        guard hasPrefix("~") else { return self }
        return replacingOccurrences(
            of: "~",
            with: fileManager.homeDirectoryForCurrentUser.path,
            range: startIndex ..< index(after: startIndex)
        )
    }
}
