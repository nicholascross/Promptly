import PromptlyKit

public protocol DetachedTaskLogSink: Sendable {
    var logPath: String? { get }

    func handle(event: PromptStreamEvent) async

    func recordCompletion(
        payload: DetachedTaskReturnPayload,
        didUseFallbackPayload: Bool
    ) async

    func recordFailure(_ error: Error) async
}
