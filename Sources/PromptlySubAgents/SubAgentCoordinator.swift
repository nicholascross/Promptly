import Foundation
import PromptlyKit

protocol SubAgentCoordinator {
    func run(
        requestMessages: [PromptMessage],
        historyEntries: [PromptHistoryEntry],
        resumeToken: String?,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult
}
