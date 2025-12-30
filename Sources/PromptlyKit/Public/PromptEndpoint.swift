import Foundation

/// Public interface for coordinating a full prompt run, including tool calls.
public protocol PromptEndpoint {
    func prompt(
        context: PromptRunContext,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult
}
