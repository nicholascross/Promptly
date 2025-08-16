import ArgumentParser
import Foundation
import PromptlyKit
import TerminalUI
import Darwin

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

    @Option(
        name: [.customLong("canned"), .customShort("p")],
        help: "Use one or more canned prompts as context."
    )
    private var cannedContexts: [String] = []

    @Option(
        name: .customLong("model"),
        help:
        """
        The model to use for the chat.
        May be an alias defined in configuration; if not specified, defaults to configuration
        """
    )
    private var model: String?

    @Flag(name: .customLong("interactive"), help: "Enable interactive prompt mode; stay open for further user input")
    private var interactive: Bool = false

    @Flag(name: .customLong("ui"), help: "Enable terminal UI mode")
    private var userInterfaceMode: Bool = false

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
        let factory = ToolFactory(fileManager: fileManager, toolsFileName: tools)

        // UI mode requires a terminal; piped stdin cannot be used with --ui
        if userInterfaceMode && isatty(STDIN_FILENO) == 0 {
            throw ValidationError("UI mode requires a TTY; piped stdin is not supported")
        }

        let initialMessages = try deriveInitialMessages()

        if userInterfaceMode {
            try await TerminalUI.run(
                config: config,
                toolFactory: factory,
                includeTools: includeTools,
                excludeTools: excludeTools,
                modelOverride: model,
                initialMessages: initialMessages
            )
            return
        }

        let availableTools = try factory.makeTools(
            config: config,
            includeTools: includeTools,
            excludeTools: excludeTools
        )

        let prompter = try Prompter(
            config: config,
            modelOverride: model,
            tools: availableTools
        )

        // If no initial messages and not in interactive mode, error
        if initialMessages.isEmpty && !interactive {
            throw ValidationError("No input provided. Usage: promptly [options] <context> or --message or piped stdin")
        }

        // Run chat stream if there are initial messages
        let conversation: [ChatMessage]
        if initialMessages.isEmpty {
            conversation = initialMessages
        } else {
            conversation = try await prompter.runChatStream(messages: initialMessages)
        }

        try await continueInteractivelyIfNeeded(prompter: prompter, initialMessages: conversation)
    }

    private func deriveInitialMessages() throws -> [ChatMessage] {
        var initialMessages: [ChatMessage] = []
        // 1. canned contexts as system messages
        for name in cannedContexts {
            let canned = try loadCannedPrompt(name: name)
            initialMessages.append(.init(role: .system, content: .text(canned)))
        }
        // 2. positional context as system message
        if let ctx = contextArgument {
            initialMessages.append(.init(role: .system, content: .text(ctx)))
        }
        // 3. piped stdin as user message (only if stdin is not a TTY and contains data)
        if isatty(STDIN_FILENO) == 0 {
            let data = FileHandle.standardInput.readDataToEndOfFile()
            if let text = String(data: data, encoding: .utf8), !text.isEmpty {
                initialMessages.append(.init(role: .user, content: .text(text)))
            }
        }
        // 4. explicit --message flags
        initialMessages += messages.chatMessages
        return initialMessages
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

    private func continueInteractivelyIfNeeded(
        prompter: Prompter,
        initialMessages: [ChatMessage]
    ) async throws {
        guard interactive else { return }
        var conversation = initialMessages
        while true {
            print("\n> ", terminator: "")
            fflush(stdout)
            guard let line = readLine() else { break }
            conversation.append(ChatMessage(role: .user, content: .text(line)))
            conversation = try await prompter.runChatStream(messages: conversation)
        }
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
