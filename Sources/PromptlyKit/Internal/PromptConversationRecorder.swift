import Foundation

actor PromptConversationRecorder {
    private var assistantBuffer = ""
    private var entries: [PromptConversationEntry]

    init(initialEntries: [PromptConversationEntry] = []) {
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

    func finish() -> [PromptConversationEntry] {
        flushAssistantBufferIfNeeded()
        return entries
    }

    private func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        entries.append(.message(PromptMessage(role: .assistant, content: .text(assistantBuffer))))
        assistantBuffer = ""
    }
}
