import Foundation
import PromptlyKitUtils

actor SubAgentTranscriptFinalizer {
    nonisolated let logPath: String?

    private let logger: SubAgentTranscriptLogger?
    private var hasFinished = false

    init(logger: SubAgentTranscriptLogger?) {
        self.logger = logger
        self.logPath = logger?.logPath
    }

    func recordCompletion(
        payload: JSONValue,
        didUseMissingReturnPayload: Bool
    ) async {
        guard !hasFinished else { return }
        hasFinished = true

        await logger?.recordReturnPayload(payload)
        let status = didUseMissingReturnPayload ? "missing_return_payload" : "completed"
        await logger?.finish(status: status, error: nil)
    }

    func recordFailure(_ error: Error) async {
        guard !hasFinished else { return }
        hasFinished = true

        await logger?.finish(status: "failed", error: error)
    }
}
