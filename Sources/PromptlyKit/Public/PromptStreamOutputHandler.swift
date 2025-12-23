import Foundation

public actor PromptStreamOutputHandler {
    public struct Output: Sendable {
        public var onAssistantText: @Sendable (String) async -> Void
        public var onToolCallRequested: @Sendable (String) async -> Void
        public var onToolCallCompleted: @Sendable (String) async -> Void

        public init(
            onAssistantText: @escaping @Sendable (String) async -> Void,
            onToolCallRequested: @escaping @Sendable (String) async -> Void,
            onToolCallCompleted: @escaping @Sendable (String) async -> Void
        ) {
            self.onAssistantText = onAssistantText
            self.onToolCallRequested = onToolCallRequested
            self.onToolCallCompleted = onToolCallCompleted
        }
    }

    private let output: Output
    private var streamedAssistantText = false

    public init(output: Output) {
        self.output = output
    }

    public var didStreamAssistantText: Bool {
        streamedAssistantText
    }

    public func handle(_ event: PromptStreamEvent) async {
        switch event {
        case let .assistantTextDelta(text):
            streamedAssistantText = true
            await output.onAssistantText(text)
        case let .toolCallRequested(_, name, _):
            await output.onToolCallRequested("Calling tool \(name)\n")
        case let .toolCallCompleted(_, _, outputValue):
            let encoder = JSONEncoder()
            if let encoded = try? String(data: encoder.encode(outputValue), encoding: .utf8) {
                await output.onToolCallCompleted(encoded + "\n")
            }
        }
    }
}
