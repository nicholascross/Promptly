import Foundation

public actor TranscriptRecorder {
    private var transcriptAccumulator: PromptTranscriptAccumulator

    public init(
        configuration: PromptTranscriptAccumulator.Configuration = .init(toolOutputPolicy: .tombstone)
    ) {
        transcriptAccumulator = PromptTranscriptAccumulator(configuration: configuration)
    }

    public func handle(_ event: PromptStreamEvent) {
        transcriptAccumulator.handle(event)
    }

    public func finishTranscript(finalAssistantText: String?) -> PromptTranscript {
        let transcript = transcriptAccumulator.finish(finalAssistantText: finalAssistantText)
        return transcript
    }
}
