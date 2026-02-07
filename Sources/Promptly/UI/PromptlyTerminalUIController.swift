import Foundation
import PromptlyConsole
import PromptlyKit
import PromptlyKitUtils
import PromptlySubAgents
import TerminalUI

@MainActor
final class PromptlyTerminalUIController {
    private let config: Config
    private let toolProvider: (@escaping @Sendable (String) -> Void) throws -> [any ExecutableTool]
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
                    await self.appendToolOutputText(text)
                },
                onToolCallCompleted: { [weak self] text in
                    guard let self else { return }
                    await self.appendToolOutputText(text)
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
        toolProvider: @escaping (@escaping @Sendable (String) -> Void) throws -> [any ExecutableTool],
        modelOverride: String?,
        initialMessages: [PromptMessage],
        apiOverride: Config.API?
    ) {
        self.config = config
        self.toolProvider = toolProvider
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

        let tools = try toolProvider(toolOutputHandler)

        let coordinator = try PromptRunCoordinator(
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
                do {
                    let result = try await runSupervisorCycleWithResumeRecovery(
                        coordinator: coordinator,
                        conversation: conversation
                    )
                    conversation = result.updatedConversation
                } catch {
                    self.appendToolOutputText("Error: \(error.localizedDescription)\n")
                }
            }
        }

        let loop = makeEventLoop()
        try await loop.run()
    }

    private func runSupervisorCycleWithResumeRecovery(
        coordinator: PromptRunCoordinator,
        conversation: [PromptMessage]
    ) async throws -> SubAgentSupervisorRunCycle {
        let supervisorRunner = SubAgentSupervisorRunner()
        do {
            return try await supervisorRunner.runMainActor(
                conversation: conversation,
                runCycle: { [self] cycleConversation in
                    self.conversation = cycleConversation
                    self.updateConversation(self.conversation)

                    let result = try await coordinator.prompt(
                        context: .messages(cycleConversation),
                        onEvent: { [weak self] event in
                            await self?.handle(event: event)
                        }
                    )
                    return SubAgentSupervisorRunCycle(
                        updatedConversation: self.conversation,
                        conversationEntries: result.conversationEntries
                    )
                }
            )
        } catch let error as SubAgentSupervisorRunnerError {
            switch error {
            case let .unresolvedResumeRecovery(toolName):
                throw PromptConsoleError.missingResumeIdForFollowUp(toolName)
            }
        } catch {
            throw error
        }
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
            case let .json(value):
                content = formatJson(value)
            case .empty:
                content = ""
            }
            let toolCallDescription = toolCallDescription(from: message.toolCalls)
            let combinedContent = combineContent(content, with: toolCallDescription)
            return "\(role): \(combinedContent)"
        }.joined(separator: "\n\n")
        Task { @MainActor in
            messagesArea.text = text
        }
    }

    private func formatJson(_ value: JSONValue) -> String {
        guard let data = try? JSONEncoder().encode(value),
              let text = String(data: data, encoding: .utf8)
        else {
            return ""
        }
        return text
    }

    private func handle(event: PromptStreamEvent) async {
        await outputHandler.handle(event)
        switch event {
        case let .toolCallRequested(id, name, arguments):
            appendToolCallMessage(id: id, name: name, arguments: arguments)
        case let .toolCallCompleted(id, _, output):
            appendToolOutputMessage(toolCallId: id, output: output)
        case .assistantTextDelta:
            break
        }
    }

    private func appendAssistantDelta(_ delta: String) {
        if conversation.last?.role != .assistant {
            conversation.append(PromptMessage(role: .assistant, content: .text(delta)))
        } else if case let .text(prev) = conversation[conversation.count - 1].content {
            let previousMessage = conversation[conversation.count - 1]
            conversation[conversation.count - 1] = PromptMessage(
                role: .assistant,
                content: .text(prev + delta),
                toolCalls: previousMessage.toolCalls,
                toolCallId: previousMessage.toolCallId
            )
        } else {
            conversation.append(PromptMessage(role: .assistant, content: .text(delta)))
        }
        updateConversation(conversation)
    }

    private func appendToolOutputText(_ text: String) {
        toolOutputArea.text += text
    }

    private func appendToolCallMessage(
        id: String?,
        name: String,
        arguments: JSONValue
    ) {
        guard let toolCallId = id else {
            return
        }
        let toolCall = PromptToolCall(id: toolCallId, name: name, arguments: arguments)
        conversation.append(
            PromptMessage(
                role: .assistant,
                content: .empty,
                toolCalls: [toolCall]
            )
        )
        updateConversation(conversation)
    }

    private func appendToolOutputMessage(
        toolCallId: String?,
        output: JSONValue
    ) {
        guard let toolCallId else {
            return
        }
        conversation.append(
            PromptMessage(
                role: .tool,
                content: .json(output),
                toolCallId: toolCallId
            )
        )
        updateConversation(conversation)
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

    private func toolCallDescription(from toolCalls: [PromptToolCall]?) -> String? {
        guard let toolCalls, !toolCalls.isEmpty else {
            return nil
        }
        let toolNames = toolCalls.map { $0.name }
        let joinedNames = toolNames.joined(separator: ", ")
        return "Tool call: \(joinedNames)"
    }

    private func combineContent(_ content: String, with toolCallDescription: String?) -> String {
        guard let toolCallDescription else {
            return content
        }
        if content.isEmpty {
            return toolCallDescription
        }
        return "\(content)\n\(toolCallDescription)"
    }
}
