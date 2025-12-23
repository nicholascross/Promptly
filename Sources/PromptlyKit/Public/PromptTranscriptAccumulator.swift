import Foundation
import PromptlyKitUtils

/// Accumulates a deterministic transcript from a stream of provider-neutral events.
public struct PromptTranscriptAccumulator {
    public struct Configuration: Sendable {
        public enum ToolOutputPolicy: Sendable {
            case include
            case tombstone
        }

        public var toolOutputPolicy: ToolOutputPolicy

        public init(toolOutputPolicy: ToolOutputPolicy = .include) {
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

    public init(
        configuration: Configuration = Configuration(),
        initialTranscript: [PromptTranscriptEntry] = []
    ) {
        self.configuration = configuration
        transcript = initialTranscript
    }

    public mutating func handle(_ event: PromptStreamEvent) {
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

    public mutating func finish() -> [PromptTranscriptEntry] {
        finish(finalAssistantText: nil)
    }

    public mutating func finish(finalAssistantText: String?) -> [PromptTranscriptEntry] {
        flushAssistantBufferIfNeeded()
        if
            let finalAssistantText,
            !finalAssistantText.isEmpty,
            !transcriptEndsWithAssistantMessage()
        {
            transcript.append(.assistant(message: finalAssistantText))
        }
        return transcript
    }

    private mutating func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        transcript.append(.assistant(message: assistantBuffer))
        assistantBuffer = ""
    }

    private func transcriptEndsWithAssistantMessage() -> Bool {
        guard let lastEntry = transcript.last else { return false }
        switch lastEntry {
        case .assistant:
            return true
        case .toolCall:
            return false
        }
    }
}
