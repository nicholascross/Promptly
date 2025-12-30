import Foundation

protocol PromptTurnEndpoint {
    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn
}
