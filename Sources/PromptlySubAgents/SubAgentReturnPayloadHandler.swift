import Foundation
import PromptlyKit
import PromptlyKitUtils

struct SubAgentReturnPayloadHandler: Sendable {
    struct Resolution: Sendable {
        let payload: JSONValue
        let didUseFallback: Bool
        let needsFollowUp: Bool
    }

    private enum PayloadKey {
        static let needsMoreInformation = "needsMoreInformation"
        static let needsSupervisorDecision = "needsSupervisorDecision"
        static let resumeIdentifier = "resumeId"
        static let logPath = "logPath"
    }

    private static let emptyAssistantFallbackText = "Sub agent response was empty."
    private static let missingReturnPayloadSummary = "Sub agent did not complete the task."
    private static let missingReturnDecisionReason = "Sub agent did not call ReturnToSupervisor after reminder."

    func extractReturnPayload(from conversationEntries: [PromptMessage]) -> JSONValue? {
        for entry in conversationEntries {
            guard entry.role == .assistant else { continue }
            guard let toolCalls = entry.toolCalls else { continue }
            for toolCall in toolCalls where toolCall.name == ReturnToSupervisorTool.toolName {
                if let output = toolOutput(
                    for: toolCall.id,
                    in: conversationEntries
                ) {
                    return output
                }
                return toolCall.arguments
            }
        }
        return nil
    }

    func resolvePayload(
        candidate: JSONValue?,
        conversationEntries: [PromptMessage]
    ) -> Resolution {
        let payload: JSONValue
        let didUseFallback: Bool

        if let candidate {
            payload = candidate
            didUseFallback = false
        } else {
            payload = missingReturnPayload(from: conversationEntries)
            didUseFallback = true
        }

        return Resolution(
            payload: payload,
            didUseFallback: didUseFallback,
            needsFollowUp: needsFollowUp(in: payload)
        )
    }

    func needsFollowUp(in payload: JSONValue) -> Bool {
        guard case let .object(object) = payload else {
            return false
        }
        let needsMoreInformation: Bool
        if case let .bool(needsMore)? = object[PayloadKey.needsMoreInformation] {
            needsMoreInformation = needsMore
        } else {
            needsMoreInformation = false
        }

        let needsSupervisorDecision: Bool
        if case let .bool(needsDecision)? = object[PayloadKey.needsSupervisorDecision] {
            needsSupervisorDecision = needsDecision
        } else {
            needsSupervisorDecision = false
        }

        return needsMoreInformation || needsSupervisorDecision
    }

    func attachLogPath(
        to payload: JSONValue,
        logPath: String?
    ) -> JSONValue {
        guard let logPath else {
            return payload
        }
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated[PayloadKey.logPath] = .string(logPath)
        return .object(updated)
    }

    func attachResumeIdentifier(
        _ resumeIdentifier: String,
        to payload: JSONValue
    ) -> JSONValue {
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated[PayloadKey.resumeIdentifier] = .string(resumeIdentifier)
        return .object(updated)
    }

    func removeResumeIdentifier(from payload: JSONValue) -> JSONValue {
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated.removeValue(forKey: PayloadKey.resumeIdentifier)
        return .object(updated)
    }

    private func toolOutput(
        for toolCallIdentifier: String?,
        in conversationEntries: [PromptMessage]
    ) -> JSONValue? {
        guard let toolCallIdentifier else {
            return nil
        }
        for entry in conversationEntries {
            guard entry.role == .tool else { continue }
            guard entry.toolCallId == toolCallIdentifier else { continue }
            if case let .json(value) = entry.content {
                return value
            }
        }
        return nil
    }

    private func missingReturnPayload(
        from conversationEntries: [PromptMessage]
    ) -> JSONValue {
        let assistantText = lastAssistantResponseText(from: conversationEntries)
        let message = """
Sub agent did not complete the task.
Last assistant response:
\(assistantText)
"""
        return .object([
            "result": .string(message),
            "summary": .string(Self.missingReturnPayloadSummary),
            "needsSupervisorDecision": .bool(true),
            "decisionReason": .string(Self.missingReturnDecisionReason),
            "supervisorMessage": .object([
                "role": .string("user"),
                "content": .string(message)
            ])
        ])
    }

    private func lastAssistantResponseText(
        from conversationEntries: [PromptMessage]
    ) -> String {
        guard let content = latestAssistantContent(in: conversationEntries) else {
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

    private func assistantText(from content: PromptContent) -> String {
        switch content {
        case let .text(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
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
