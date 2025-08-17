import Foundation
import PromptlyKit
import TerminalUI

@MainActor
final class PromptlyTerminalUIController {
    private let config: Config
    private let toolFactory: ToolFactory
    private let includeTools: [String]
    private let excludeTools: [String]
    private let modelOverride: String?
    private let initialMessages: [ChatMessage]

    // UI components
    private let terminal: Terminal
    private let input: TextInputWidget
    private let messagesArea: TextAreaWidget
    private let toolOutputArea: TextAreaWidget

    init(
        config: Config,
        toolFactory: ToolFactory,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        modelOverride: String?,
        initialMessages: [ChatMessage]
    ) {
        self.config = config
        self.toolFactory = toolFactory
        self.includeTools = includeTools
        self.excludeTools = excludeTools
        self.modelOverride = modelOverride
        self.initialMessages = initialMessages

        terminal = Terminal()
        terminal.hideCursor()
        terminal.clearScreen()

        input = TextInputWidget(prompt: "> ", title: "Message")
        messagesArea = TextAreaWidget(text: "", title: "Conversation")
        toolOutputArea = TextAreaWidget(text: "", title: "Tool Calls")
    }

    func run() async throws {
        defer { teardown() }

        let toolOutputHandler = { @Sendable text in
            Task { @MainActor in
                self.toolOutputArea.text += text
            }
            return
        }

        var conversation: [ChatMessage] = initialMessages
        updateConversation(conversation)

        // Create shell-command tools with UI streaming handler
        let tools = try toolFactory.makeTools(
            config: config,
            includeTools: includeTools,
            excludeTools: excludeTools,
            toolOutput: toolOutputHandler
        )

        // Create a Prompter that streams directly into the UI
        let prompter = try Prompter(
            config: config,
            modelOverride: modelOverride,
            tools: tools,
            output: { [weak self] text in
                guard let self else { return }
                Task { @MainActor in
                    // Append or update the current assistant message
                    if conversation.last?.role != .assistant {
                        conversation.append(ChatMessage(role: .assistant, content: .text(text)))
                    } else if case let .text(prev) = conversation[conversation.count - 1].content {
                        conversation[conversation.count - 1] =
                            ChatMessage(role: .assistant, content: .text(prev + text))
                    }
                    self.updateConversation(conversation)
                }
            },
            toolOutput: toolOutputHandler
        )

        input.onSubmit = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in
                toolOutputArea.text = ""
                conversation.append(ChatMessage(role: .user, content: .text(text)))
                self.updateConversation(conversation)
                let updated = try await prompter.runChatStream(messages: conversation)
                conversation = updated
                self.updateConversation(conversation)
            }
        }

        let loop = makeEventLoop()
        try await loop.run()
    }

    /// Creates an event loop for this UI, wiring layout to the terminal.
    private func makeEventLoop() -> UIEventLoop {
        UIEventLoop(terminal: terminal) {
            Stack(axis: .vertical, spacing: 0) {
                self.input.expanding(maxHeight: 5)
                self.messagesArea
                self.toolOutputArea.frame(height: 10)
            }
        }
    }

    /// Updates the conversation display with the latest messages.
    private func updateConversation(_ conversation: [ChatMessage]) {
        let text = conversation.map { message -> String in
            let role = message.role.rawValue.capitalized
            let content: String
            switch message.content {
            case let .text(str):
                content = str
            case let .blocks(blocks):
                content = blocks.map { $0.text }.joined()
            case .empty:
                content = ""
            }
            return "\(role): \(content)"
        }.joined(separator: "\n\n")
        Task { @MainActor in
            messagesArea.text = text
        }
    }

    /// Returns a handler that appends tool output to the tool output area.
    private func makeToolOutputHandler() -> @Sendable (String) -> Void {
        { text in
            Task { @MainActor in
                self.toolOutputArea.text += text
            }
        }
    }

    /// Restores terminal state by showing cursor and clearing the screen.
    private func teardown() {
        terminal.showCursor()
        terminal.clearScreen()
    }
}
