import Darwin
import Foundation

public final class StreamingOutputSink: @unchecked Sendable {
    private let lock = NSLock()
    private var streamedAssistantText = false

    public init() {}

    public var didStreamAssistantText: Bool {
        lock.lock()
        let value = streamedAssistantText
        lock.unlock()
        return value
    }

    public func handle(_ event: PromptStreamEvent) {
        switch event {
        case let .assistantTextDelta(text):
            lock.lock()
            streamedAssistantText = true
            lock.unlock()
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
