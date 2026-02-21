import Foundation
import PromptlyKit
import PromptlyKitUtils

public enum SubAgentSupervisorRecovery {
    public static func toolNeedingResumeRecovery(
        conversationEntries: [PromptMessage]
    ) -> String? {
        var toolNameByIdentifier: [String: String] = [:]
        var latestToolNeedingRecovery: String?

        for entry in conversationEntries {
            if entry.role == .assistant, let toolCalls = entry.toolCalls {
                for toolCall in toolCalls where isSubAgentTool(name: toolCall.name) {
                    guard let toolCallIdentifier = toolCall.id else {
                        continue
                    }
                    toolNameByIdentifier[toolCallIdentifier] = toolCall.name
                }
                continue
            }

            guard entry.role == .tool else {
                continue
            }
            guard let toolCallIdentifier = entry.toolCallId else {
                continue
            }
            guard let toolName = toolNameByIdentifier[toolCallIdentifier] else {
                continue
            }
            guard case let .json(payload) = entry.content else {
                continue
            }
            if requiresResumeRecovery(payload: payload) {
                latestToolNeedingRecovery = toolName
            }
        }

        return latestToolNeedingRecovery
    }

    public static func recoveryPrompt(toolName: String) -> String {
        """
        The latest \(toolName) output requested a follow up but did not include a valid resumeId.
        Call \(toolName) again now and ensure the output includes a valid resumeId for continuation.
        Do not ask the user for additional details in this recovery step.
        """
    }

    public static func requiresResumeRecovery(payload: JSONValue) -> Bool {
        guard needsFollowUp(payload: payload) else {
            return false
        }
        return !hasValidResumeId(payload: payload)
    }

    private static func isSubAgentTool(name: String) -> Bool {
        name.hasPrefix("SubAgent-")
    }

    private static func needsFollowUp(payload: JSONValue) -> Bool {
        guard case let .object(object) = payload else {
            return false
        }
        let needsMoreInformation = boolValue(object["needsMoreInformation"]) == true
        let needsSupervisorDecision = boolValue(object["needsSupervisorDecision"]) == true
        return needsMoreInformation || needsSupervisorDecision
    }

    private static func hasValidResumeId(payload: JSONValue) -> Bool {
        guard case let .object(object) = payload else {
            return false
        }
        guard case let .string(resumeIdentifier)? = object["resumeId"] else {
            return false
        }
        return SubAgentResumeIdentifier.isValid(resumeIdentifier)
    }

    private static func boolValue(_ value: JSONValue?) -> Bool? {
        guard case let .bool(booleanValue)? = value else {
            return nil
        }
        return booleanValue
    }
}
