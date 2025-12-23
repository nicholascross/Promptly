import Foundation

actor TranscriptRecorder {
    private var transcriptAccumulator: PromptTranscriptAccumulator

    init(
        configuration: PromptTranscriptAccumulator.Configuration = .init(toolOutputPolicy: .tombstone)
    ) {
        transcriptAccumulator = PromptTranscriptAccumulator(configuration: configuration)
    }

    func handle(_ event: PromptStreamEvent) {
        transcriptAccumulator.handle(event)
    }

    func finishTranscript(finalAssistantText: String?) -> [PromptTranscriptEntry] {
        let transcript = transcriptAccumulator.finish(finalAssistantText: finalAssistantText)
        return transcript
    }
}
