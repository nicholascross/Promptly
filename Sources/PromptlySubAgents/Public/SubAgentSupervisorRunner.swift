import Foundation
import PromptlyKit

public struct SubAgentSupervisorRunCycle: Sendable {
    public let updatedConversation: [PromptMessage]
    public let conversationEntries: [PromptMessage]

    public init(
        updatedConversation: [PromptMessage],
        conversationEntries: [PromptMessage]
    ) {
        self.updatedConversation = updatedConversation
        self.conversationEntries = conversationEntries
    }
}

public enum SubAgentSupervisorRunnerError: Error, LocalizedError, Sendable {
    case unresolvedResumeRecovery(toolName: String)

    public var errorDescription: String? {
        switch self {
        case let .unresolvedResumeRecovery(toolName):
            return "Follow up for \(toolName) requires a valid resumeId, but recovery did not produce one."
        }
    }
}

public struct SubAgentSupervisorRunner: Sendable {
    public let maximumRecoveryAttempts: Int

    public init(maximumRecoveryAttempts: Int = 1) {
        self.maximumRecoveryAttempts = max(0, maximumRecoveryAttempts)
    }

    public func run(
        conversation: [PromptMessage],
        runCycle: ([PromptMessage]) async throws -> SubAgentSupervisorRunCycle
    ) async throws -> SubAgentSupervisorRunCycle {
        try await runWithRecovery(conversation: conversation, runCycle: runCycle)
    }

    @MainActor
    public func runMainActor(
        conversation: [PromptMessage],
        runCycle: @MainActor ([PromptMessage]) async throws -> SubAgentSupervisorRunCycle
    ) async throws -> SubAgentSupervisorRunCycle {
        try await runWithRecovery(conversation: conversation, runCycle: runCycle)
    }

    private func runWithRecovery(
        conversation: [PromptMessage],
        runCycle: ([PromptMessage]) async throws -> SubAgentSupervisorRunCycle
    ) async throws -> SubAgentSupervisorRunCycle {
        var attempts = 0
        var latestCycle = try await runCycle(conversation)

        while let toolName = SubAgentSupervisorRecovery.toolNeedingResumeRecovery(
            conversationEntries: latestCycle.conversationEntries
        ) {
            guard attempts < maximumRecoveryAttempts else {
                throw SubAgentSupervisorRunnerError.unresolvedResumeRecovery(toolName: toolName)
            }
            attempts += 1

            var recoveryConversation = latestCycle.updatedConversation
            recoveryConversation.append(
                PromptMessage(
                    role: .user,
                    content: .text(SubAgentSupervisorRecovery.recoveryPrompt(toolName: toolName))
                )
            )
            latestCycle = try await runCycle(recoveryConversation)
        }

        return latestCycle
    }
}
