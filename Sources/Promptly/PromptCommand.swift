import ArgumentParser
import Foundation
import PromptlyKit
import PromptlyKitTooling
import TerminalUI
import Darwin

private let fileManager = FileManager()

struct PromptCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prompt",
        abstract: "Send a prompt to the AI chat interface"
    )

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

    @Option(
        name: .customLong("api"),
        help: "Select backend API (responses or chat). Overrides configuration."
    )
    private var api: APISelection?

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

        let initialMessages = try deriveInitialMessages()

        if userInterfaceMode {
            // If stdin was piped (consumed) and not a TTY, reopen /dev/tty so UI can read input
            if isatty(STDIN_FILENO) == 0 {
                _ = freopen("/dev/tty", "r", stdin)
            }
            let controller = await PromptlyTerminalUIController(
                config: config,
                toolFactory: factory,
                includeTools: includeTools,
                excludeTools: excludeTools,
                modelOverride: model,
                initialMessages: initialMessages,
                apiOverride: api?.configValue
            )
            try await controller.run()
            return
        }

        let availableTools = try factory.makeTools(
            config: config,
            includeTools: includeTools,
            excludeTools: excludeTools
        )

        let coordinator = try PrompterCoordinator(
            config: config,
            modelOverride: model,
            apiOverride: api?.configValue,
            tools: availableTools
        )

        // If no initial messages and not in interactive mode, error
        if initialMessages.isEmpty && !interactive {
            throw ValidationError("No input provided. Usage: promptly prompt [options] <context> or --message or piped stdin")
        }

        var conversation: [ChatMessage] = initialMessages
        if !conversation.isEmpty {
            let (updatedConversation, _) = try await runOnce(
                coordinator: coordinator,
                conversation: conversation
            )
            conversation = updatedConversation
        }

        try await continueInteractivelyIfNeeded(
            coordinator: coordinator,
            initialMessages: conversation
        )
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
        coordinator: PrompterCoordinator,
        initialMessages: [ChatMessage]
    ) async throws {
        guard interactive else { return }
        // If stdin has been consumed (e.g. piped input) and is not a TTY,
        // reopen /dev/tty so further interactive reads come from the terminal.
        if isatty(STDIN_FILENO) == 0 {
            _ = freopen("/dev/tty", "r", stdin)
        }
        var conversation = initialMessages
        while true {
            print("\n> ", terminator: "")
            fflush(stdout)
            guard let line = readLine() else { break }
            conversation.append(ChatMessage(role: .user, content: .text(line)))

            let (updatedConversation, _) = try await runOnce(
                coordinator: coordinator,
                conversation: conversation
            )
            conversation = updatedConversation
        }
    }

    private func runOnce(
        coordinator: PrompterCoordinator,
        conversation: [ChatMessage]
    ) async throws -> (conversation: [ChatMessage], transcript: PromptTranscript) {
        let runState = RunState()

        let result = try await coordinator.run(
            messages: conversation,
            onEvent: { event in
                runState.handle(event)
            }
        )

        let transcript = runState.finishTranscript(finalAssistantText: result.finalAssistantText)

        var updatedConversation = conversation
        if let assistantText = result.finalAssistantText, !assistantText.isEmpty {
            updatedConversation.append(ChatMessage(role: .assistant, content: .text(assistantText)))
        }

        if let assistantText = result.finalAssistantText, !assistantText.isEmpty, !runState.didStreamAssistantText {
            fputs(assistantText, stdout)
            fputs("\n", stdout)
            fflush(stdout)
        } else if runState.didStreamAssistantText {
            fputs("\n", stdout)
            fflush(stdout)
        }

        return (updatedConversation, transcript)
    }
}

private final class RunState: @unchecked Sendable {
    private let lock = NSLock()
    private var transcriptAccumulator = PromptTranscriptAccumulator(
        configuration: .init(toolOutputPolicy: .tombstone)
    )
    private var streamedAssistantText = false

    var didStreamAssistantText: Bool {
        lock.lock()
        let value = streamedAssistantText
        lock.unlock()
        return value
    }

    func handle(_ event: PromptStreamEvent) {
        lock.lock()
        transcriptAccumulator.handle(event)
        if case .assistantTextDelta = event {
            streamedAssistantText = true
        }
        lock.unlock()

        switch event {
        case let .assistantTextDelta(text):
            fputs(text, stdout)
            fflush(stdout)
        case let .toolCallRequested(_, name, _):
            fputs("Calling tool \(name)\n", stdout)
            fflush(stdout)
        case let .toolCallCompleted(_, _, output):
            let encoder = JSONEncoder()
            if let encoded = try? String(data: encoder.encode(output), encoding: .utf8) {
                fputs(encoded + "\n", stdout)
                fflush(stdout)
            }
        }
    }

    func finishTranscript(finalAssistantText: String?) -> PromptTranscript {
        lock.lock()
        let transcript = transcriptAccumulator.finish(finalAssistantText: finalAssistantText)
        lock.unlock()
        return transcript
    }
}

    private enum APISelection: ExpressibleByArgument {
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
