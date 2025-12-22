import Foundation
import PromptlyKitUtils

public struct PromptTranscript: Sendable {
    public var entries: [PromptTranscriptEntry]

    public init(entries: [PromptTranscriptEntry] = []) {
        self.entries = entries
    }
}

public enum PromptTranscriptEntry: Sendable {
    case assistant(message: String)
    case toolCall(id: String?, name: String, arguments: JSONValue?, output: JSONValue?)
}

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
    private var transcript: PromptTranscript

    public init(
        configuration: Configuration = Configuration(),
        initialTranscript: PromptTranscript = PromptTranscript()
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
                transcript.entries.append(.toolCall(id: nil, name: name, arguments: arguments, output: nil))
            }

        case let .toolCallCompleted(id, name, output):
            flushAssistantBufferIfNeeded()

            let persistedOutput: JSONValue? = switch configuration.toolOutputPolicy {
            case .include: output
            case .tombstone: .string("[tool output omitted]")
            }

            if let id, let pending = pendingToolCallsById.removeValue(forKey: id) {
                transcript.entries.append(
                    .toolCall(id: id, name: pending.name, arguments: pending.arguments, output: persistedOutput)
                )
            } else {
                transcript.entries.append(
                    .toolCall(id: id, name: name, arguments: nil, output: persistedOutput)
                )
            }
        }
    }

    public mutating func finish() -> PromptTranscript {
        finish(finalAssistantText: nil)
    }

    public mutating func finish(finalAssistantText: String?) -> PromptTranscript {
        flushAssistantBufferIfNeeded()
        if
            let finalAssistantText,
            !finalAssistantText.isEmpty,
            !transcriptEndsWithAssistantMessage()
        {
            transcript.entries.append(.assistant(message: finalAssistantText))
        }
        return transcript
    }

    private mutating func flushAssistantBufferIfNeeded() {
        guard !assistantBuffer.isEmpty else { return }
        transcript.entries.append(.assistant(message: assistantBuffer))
        assistantBuffer = ""
    }

    private func transcriptEndsWithAssistantMessage() -> Bool {
        guard let lastEntry = transcript.entries.last else { return false }
        switch lastEntry {
        case .assistant:
            return true
        case .toolCall:
            return false
        }
    }
}
