import Darwin
import Foundation

public actor StreamingOutputSink {
    private var streamedAssistantText = false

    public init() {}

    public var didStreamAssistantText: Bool {
        streamedAssistantText
    }

    public func handle(_ event: PromptStreamEvent) {
        switch event {
        case let .assistantTextDelta(text):
            streamedAssistantText = true
            fputs(text, stdout)
            fflush(stdout)
        case let .toolCallRequested(_, name, _):
            fputs("Calling tool \(name)\n", stdout)
            fflush(stdout)
        case let .toolCallCompleted(_, _, output):
            let encoder = JSONEncoder()
            if let encoded = try? String(data: encoder.encode(output), encoding: .utf8) {
                fputs(encoded + "\n", stdout)
                fflush(stdout)
            }
        }
    }
}
