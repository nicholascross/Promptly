import Foundation
import PromptlyKit
import PromptlyKitTooling
import TerminalUI

@MainActor
final class PromptlyTerminalUIController {
    private let config: Config
    private let toolFactory: ToolFactory
    private let includeTools: [String]
    private let excludeTools: [String]
    private let modelOverride: String?
    private let initialMessages: [PromptMessage]
    private let apiOverride: Config.API?
    private var conversation: [PromptMessage]
    private lazy var outputHandler: PromptStreamOutputHandler = {
        PromptStreamOutputHandler(
            output: .init(
                onAssistantText: { [weak self] text in
                    guard let self else { return }
                    await self.appendAssistantDelta(text)
                },
                onToolCallRequested: { [weak self] text in
                    guard let self else { return }
                    await self.appendToolOutput(text)
                },
                onToolCallCompleted: { [weak self] text in
                    guard let self else { return }
                    await self.appendToolOutput(text)
                }
            )
        )
    }()

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
        initialMessages: [PromptMessage],
        apiOverride: Config.API?
    ) {
        self.config = config
        self.toolFactory = toolFactory
        self.includeTools = includeTools
        self.excludeTools = excludeTools
        self.modelOverride = modelOverride
        self.initialMessages = initialMessages
        self.apiOverride = apiOverride
        conversation = initialMessages

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

        updateConversation(conversation)

        // Create shell-command tools with UI streaming handler
        let tools = try toolFactory.makeTools(
            config: config,
            includeTools: includeTools,
            excludeTools: excludeTools,
            toolOutput: toolOutputHandler
        )

        let coordinator = try PrompterCoordinator(
            config: config,
            modelOverride: modelOverride,
            apiOverride: apiOverride,
            tools: tools
        )

        input.onSubmit = { [weak self] text in
            guard let self else { return }
            Task { @MainActor in
                toolOutputArea.text = ""
                conversation.append(PromptMessage(role: .user, content: .text(text)))
                self.updateConversation(conversation)
                let result = try await coordinator.run(
                    messages: conversation,
                    onEvent: { [weak self] event in
                        await self?.handle(event: event)
                    }
                )

                if let assistantText = result.finalAssistantText, !assistantText.isEmpty {
                    if conversation.last?.role == .assistant {
                        conversation[conversation.count - 1] = PromptMessage(role: .assistant, content: .text(assistantText))
                    } else {
                        conversation.append(PromptMessage(role: .assistant, content: .text(assistantText)))
                    }
                }

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
    private func updateConversation(_ conversation: [PromptMessage]) {
        let text = conversation.map { message -> String in
            let role = message.role.rawValue.capitalized
            let content: String
            switch message.content {
            case let .text(str):
                content = str
            case .empty:
                content = ""
            }
            return "\(role): \(content)"
        }.joined(separator: "\n\n")
        Task { @MainActor in
            messagesArea.text = text
        }
    }

    private func handle(event: PromptStreamEvent) async {
        await outputHandler.handle(event)
    }

    private func appendAssistantDelta(_ delta: String) {
        if conversation.last?.role != .assistant {
            conversation.append(PromptMessage(role: .assistant, content: .text(delta)))
        } else if case let .text(prev) = conversation[conversation.count - 1].content {
            conversation[conversation.count - 1] = PromptMessage(
                role: .assistant,
                content: .text(prev + delta)
            )
        }
        updateConversation(conversation)
    }

    private func appendToolOutput(_ text: String) {
        toolOutputArea.text += text
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
