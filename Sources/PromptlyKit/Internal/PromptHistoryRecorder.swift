import Foundation

actor PromptHistoryRecorder {
    private var assistantBuffer = ""
    private var entries: [PromptHistoryEntry]

    init(initialEntries: [PromptHistoryEntry] = []) {
        entries = initialEntries
    }

    func handle(_ event: PromptStreamEvent) {
        switch event {
        case let .assistantTextDelta(text):
            assistantBuffer += text

        case let .toolCallRequested(id, name, arguments):
            flushAssistantBufferIfNeeded()
            entries.append(.toolCall(id: id, name: name, arguments: arguments))

        case let .toolCallCompleted(id, _, output):
            flushAssistantBufferIfNeeded()
            entries.append(.toolOutput(toolCallId: id, output: output))
        }
    }

    func finish() -> [PromptHistoryEntry] {
        flushAssistantBufferIfNeeded()
        return entries
    }

    private func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        entries.append(.message(PromptMessage(role: .assistant, content: .text(assistantBuffer))))
        assistantBuffer = ""
    }
}
