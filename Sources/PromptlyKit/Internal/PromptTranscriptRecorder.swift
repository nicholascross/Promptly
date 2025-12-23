import Foundation
import PromptlyKitUtils

actor PromptTranscriptRecorder {
    struct Configuration: Sendable {
        enum ToolOutputPolicy: Sendable {
            case include
            case tombstone
        }

        var toolOutputPolicy: ToolOutputPolicy

        init(toolOutputPolicy: ToolOutputPolicy = .tombstone) {
            self.toolOutputPolicy = toolOutputPolicy
        }
    }

    private struct PendingToolCall {
        let id: String?
        let name: String
        let arguments: JSONValue
    }

    private var configuration: Configuration
    private var assistantBuffer = ""
    private var pendingToolCallsById: [String: PendingToolCall] = [:]
    private var transcript: [PromptTranscriptEntry]

    init(
        configuration: Configuration = .init(),
        initialTranscript: [PromptTranscriptEntry] = []
    ) {
        self.configuration = configuration
        transcript = initialTranscript
    }

    func handle(_ event: PromptStreamEvent) {
        switch event {
        case let .assistantTextDelta(text):
            assistantBuffer += text

        case let .toolCallRequested(id, name, arguments):
            flushAssistantBufferIfNeeded()
            let pending = PendingToolCall(id: id, name: name, arguments: arguments)
            if let id {
                pendingToolCallsById[id] = pending
            } else {
                transcript.append(.toolCall(id: nil, name: name, arguments: arguments, output: nil))
            }

        case let .toolCallCompleted(id, name, output):
            flushAssistantBufferIfNeeded()

            let persistedOutput: JSONValue? = switch configuration.toolOutputPolicy {
            case .include: output
            case .tombstone: .string("[tool output omitted]")
            }

            if let id, let pending = pendingToolCallsById.removeValue(forKey: id) {
                transcript.append(
                    .toolCall(id: id, name: pending.name, arguments: pending.arguments, output: persistedOutput)
                )
            } else {
                transcript.append(
                    .toolCall(id: id, name: name, arguments: nil, output: persistedOutput)
                )
            }
        }
    }

    func finish() -> [PromptTranscriptEntry] {
        flushAssistantBufferIfNeeded()
        return transcript
    }

    private func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        transcript.append(.assistant(message: assistantBuffer))
        assistantBuffer = ""
    }

}
