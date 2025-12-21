import Foundation

public final class TranscriptRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var transcriptAccumulator = PromptTranscriptAccumulator(
        configuration: .init(toolOutputPolicy: .tombstone)
    )

    public init() {}

    public func handle(_ event: PromptStreamEvent) {
        lock.lock()
        transcriptAccumulator.handle(event)
        lock.unlock()
    }

    public func finishTranscript(finalAssistantText: String?) -> PromptTranscript {
        lock.lock()
        let transcript = transcriptAccumulator.finish(finalAssistantText: finalAssistantText)
        lock.unlock()
        return transcript
    }
}
