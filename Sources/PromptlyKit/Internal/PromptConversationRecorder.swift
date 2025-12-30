import Foundation

actor PromptConversationRecorder {
    private var assistantBuffer = ""
    private var entries: [PromptMessage]

    init() {
        entries = []
    }

    func handle(_ event: PromptStreamEvent) {
        switch event {
        case let .assistantTextDelta(text):
            assistantBuffer += text

        case let .toolCallRequested(id, name, arguments):
            flushAssistantBufferIfNeeded()
            entries.append(
                PromptMessage(
                    role: .assistant,
                    content: .empty,
                    toolCalls: [
                        PromptToolCall(
                            id: id,
                            name: name,
                            arguments: arguments
                        )
                    ]
                )
            )

        case let .toolCallCompleted(id, _, output):
            flushAssistantBufferIfNeeded()
            entries.append(
                PromptMessage(
                    role: .tool,
                    content: .json(output),
                    toolCallId: id
                )
            )
        }
    }

    func finish() -> [PromptMessage] {
        flushAssistantBufferIfNeeded()
        return entries
    }

    private func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        entries.append(PromptMessage(role: .assistant, content: .text(assistantBuffer)))
        assistantBuffer = ""
    }
}
