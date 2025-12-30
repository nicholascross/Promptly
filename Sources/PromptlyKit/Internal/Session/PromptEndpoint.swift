import Foundation

protocol PromptEndpoint {
    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn
}
