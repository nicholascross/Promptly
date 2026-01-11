import Foundation
import PromptlyKit
import PromptlyKitUtils

public struct DetachedTaskReturnPayloadResolver: DetachedTaskReturnPayloadResolving {
    private static let emptyAssistantFallbackText = "Sub agent response was empty."
    private static let missingReturnPayloadSummary = "Sub agent did not complete the task."
    private static let missingReturnDecisionReason = "Sub agent did not call ReturnToSupervisor after reminder."

    private let returnToolName: String

    public init(returnToolName: String) {
        self.returnToolName = returnToolName
    }

    public func extractReturnPayload(
        from conversationEntries: [PromptMessage]
    ) -> DetachedTaskReturnPayload? {
        let outputsByIdentifier = toolOutputsByIdentifier(
            in: conversationEntries
        )
        guard let lastToolCall = lastReturnToolCall(
            in: conversationEntries
        ) else {
            return nil
        }

        if let identifier = lastToolCall.id,
           let outputValue = outputsByIdentifier[identifier],
           let outputPayload = decodePayload(from: outputValue) {
            return outputPayload
        }

        return decodePayload(from: lastToolCall.arguments)
    }

    public func resolvePayload(
        candidate: DetachedTaskReturnPayload?,
        conversationEntries: [PromptMessage]
    ) -> DetachedTaskReturnPayloadResolution {
        if let candidate {
            return DetachedTaskReturnPayloadResolution(
                payload: candidate,
                didUseFallback: false
            )
        }

        let fallbackPayload = missingReturnPayload(
            from: conversationEntries
        )
        return DetachedTaskReturnPayloadResolution(
            payload: fallbackPayload,
            didUseFallback: true
        )
    }

    public func needsFollowUp(
        in payload: DetachedTaskReturnPayload
    ) -> Bool {
        let needsMoreInformation = payload.needsMoreInformation == true
        let needsSupervisorDecision = payload.needsSupervisorDecision == true
        return needsMoreInformation || needsSupervisorDecision
    }

    private func lastReturnToolCall(
        in conversationEntries: [PromptMessage]
    ) -> PromptToolCall? {
        var lastToolCall: PromptToolCall?
        for entry in conversationEntries {
            guard entry.role == .assistant else { continue }
            guard let toolCalls = entry.toolCalls else { continue }
            for toolCall in toolCalls where toolCall.name == returnToolName {
                lastToolCall = toolCall
            }
        }
        return lastToolCall
    }

    private func toolOutputsByIdentifier(
        in conversationEntries: [PromptMessage]
    ) -> [String: JSONValue] {
        var outputs: [String: JSONValue] = [:]
        for entry in conversationEntries {
            guard entry.role == .tool else { continue }
            guard let identifier = entry.toolCallId else { continue }
            guard case let .json(value) = entry.content else { continue }
            outputs[identifier] = value
        }
        return outputs
    }

    private func decodePayload(
        from value: JSONValue
    ) -> DetachedTaskReturnPayload? {
        do {
            return try value.decoded(DetachedTaskReturnPayload.self)
        } catch {
            return nil
        }
    }

    private func missingReturnPayload(
        from conversationEntries: [PromptMessage]
    ) -> DetachedTaskReturnPayload {
        let assistantText = lastAssistantResponseText(
            from: conversationEntries
        )
        let message = """
Sub agent did not complete the task.
Last assistant response:
\(assistantText)
"""
        return DetachedTaskReturnPayload(
            result: message,
            summary: Self.missingReturnPayloadSummary,
            artifacts: nil,
            evidence: nil,
            confidence: nil,
            needsMoreInformation: nil,
            requestedInformation: nil,
            needsSupervisorDecision: true,
            decisionReason: Self.missingReturnDecisionReason,
            nextActionAdvice: nil,
            resumeId: nil,
            logPath: nil,
            supervisorMessage: DetachedTaskSupervisorMessage(
                role: "user",
                content: message
            )
        )
    }

    private func lastAssistantResponseText(
        from conversationEntries: [PromptMessage]
    ) -> String {
        guard let content = latestAssistantContent(
            in: conversationEntries
        ) else {
            return Self.emptyAssistantFallbackText
        }
        return assistantText(from: content)
    }

    private func latestAssistantContent(
        in conversationEntries: [PromptMessage]
    ) -> PromptContent? {
        for entry in conversationEntries.reversed() {
            guard entry.role == .assistant else { continue }
            return entry.content
        }
        return nil
    }

    private func assistantText(
        from content: PromptContent
    ) -> String {
        switch content {
        case let .text(text):
            let trimmed = text.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            return trimmed.isEmpty ? Self.emptyAssistantFallbackText : text
        case let .json(value):
            return encodedJSONText(from: value) ?? value.description
        case .empty:
            return Self.emptyAssistantFallbackText
        }
    }

    private func encodedJSONText(from value: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
