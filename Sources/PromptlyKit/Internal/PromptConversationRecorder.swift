import Foundation

actor PromptConversationRecorder {
    private var assistantBuffer = ""
    private var entries: [PromptMessage]
    private var pendingError: PromptRunExecutorError?

    init() {
        entries = []
    }

    func handle(_ event: PromptStreamEvent) {
        switch event {
        case let .assistantTextDelta(text):
            assistantBuffer += text

        case let .toolCallRequested(id, name, arguments):
            guard let id else {
                recordError(.missingToolCallIdentifier)
                return
            }
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
            guard let id else {
                recordError(.missingToolOutputIdentifier)
                return
            }
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

    func finish() throws -> [PromptMessage] {
        flushAssistantBufferIfNeeded()
        if let pendingError {
            throw pendingError
        }
        return entries
    }

    private func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        entries.append(PromptMessage(role: .assistant, content: .text(assistantBuffer)))
        assistantBuffer = ""
    }

    private func recordError(_ error: PromptRunExecutorError) {
        if pendingError == nil {
            pendingError = error
        }
    }
}
