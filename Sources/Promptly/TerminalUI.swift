import Foundation
import PromptlyKit
import TerminalUI

/// UI mode for Promptly, providing a basic chat messaging interface powered by TerminalUI.
enum TerminalUI {
    /// Runs the example TerminalUI application.
    @MainActor
    static func run(
        configURL: URL,
        toolsFileName: String,
        includeTools: [String],
        excludeTools: [String],
        modelOverride: String?
    ) async throws {
        let terminal = Terminal()
        terminal.hideCursor()
        terminal.clearScreen()
        defer {
            terminal.showCursor()
            terminal.clearScreen()
        }

        // Load configuration and tools
        let config = try Config.loadConfig(url: configURL)
        var availableTools = try [PromptTool()]
            + ToolFactory(fileManager: FileManager(), toolsFileName: toolsFileName)
            .makeTools(config: config)
        if !includeTools.isEmpty {
            availableTools = availableTools.filter { tool in
                includeTools.contains { include in tool.name.contains(include) }
            }
        }
        if !excludeTools.isEmpty {
            availableTools = availableTools.filter { tool in
                !excludeTools.contains { exclude in tool.name.contains(exclude) }
            }
        }
        // Conversation history
        var conversation: [ChatMessage] = []

        // Widget for displaying messages
        let messagesArea = TextAreaWidget(text: "", title: "Conversation")

        // Helper to render conversation
        func renderConversation() {
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

        // Create a Prompter that streams directly into the UI
        let prompter = try Prompter(
            config: config,
            modelOverride: modelOverride,
            tools: availableTools,
            output: { text in
                // Ensure UI updates and conversation mutations on the main actor
                Task { @MainActor in
                    // Append or update the current assistant message
                    if conversation.last?.role != .assistant {
                        conversation.append(ChatMessage(role: .assistant, content: .text(text)))
                    } else if case let .text(prev) = conversation[conversation.count - 1].content {
                        conversation[conversation.count - 1] =
                            ChatMessage(role: .assistant, content: .text(prev + text))
                    }
                    renderConversation()
                }
            }
        )

        // Input widget for user messages
        let input = TextInputWidget(prompt: "> ", title: "Message")

        input.onSubmit = { text in
            Task { @MainActor in
                conversation.append(ChatMessage(role: .user, content: .text(text)))
                renderConversation()
                let updated = try await prompter.runChatStream(messages: conversation)
                conversation = updated
                renderConversation()
            }
        }

        // Layout and run UI
        let loop = UIEventLoop(terminal: terminal) {
            Stack(axis: .vertical, spacing: 0) {
                messagesArea
                input.frame(height: 3)
            }
        }
        try await loop.run()
    }
}
