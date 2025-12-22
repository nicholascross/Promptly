import Foundation

public struct PromptSessionRunner {
    public struct Configuration: Sendable {
        public let maximumToolIterations: Int

        public init(maximumToolIterations: Int = 8) {
            self.maximumToolIterations = max(0, maximumToolIterations)
        }
    }

    private let endpoint: any PromptEndpoint
    private let toolGateway: any ToolExecutionGateway
    private let configuration: Configuration

    public init(
        endpoint: any PromptEndpoint,
        toolGateway: any ToolExecutionGateway,
        configuration: Configuration = Configuration()
    ) {
        self.endpoint = endpoint
        self.toolGateway = toolGateway
        self.configuration = configuration
    }

    public func run(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        let transcriptRecorder = TranscriptRecorder(
            configuration: .init(toolOutputPolicy: .include)
        )

        let eventHandler: @Sendable (PromptStreamEvent) async -> Void = { event in
            await transcriptRecorder.handle(event)
            await onEvent(event)
        }

        var turn = try await endpoint.start(messages: messages, onEvent: eventHandler)

        var toolIterations = 0
        while !turn.toolCalls.isEmpty {
            toolIterations += 1
            if toolIterations > configuration.maximumToolIterations {
                throw PromptSessionRunnerError.toolIterationLimitExceeded(limit: configuration.maximumToolIterations)
            }

            let toolOutputs = try await executeTools(
                toolCalls: turn.toolCalls,
                onEvent: eventHandler
            )

            guard let continuation = turn.continuation else {
                throw PromptSessionRunnerError.missingContinuationToken
            }

            turn = try await endpoint.continueSession(
                continuation: continuation,
                toolOutputs: toolOutputs,
                onEvent: eventHandler
            )
        }

        let promptTranscript = await transcriptRecorder.finishTranscript(finalAssistantText: turn.finalAssistantText)
        return PromptSessionResult(
            finalAssistantText: turn.finalAssistantText,
            finalTurn: turn,
            promptTranscript: promptTranscript
        )
    }

    private func executeTools(
        toolCalls: [ToolCallRequest],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> [ToolCallOutput] {
        var outputs: [ToolCallOutput] = []
        outputs.reserveCapacity(toolCalls.count)

        for call in toolCalls {
            await onEvent(.toolCallRequested(id: call.id, name: call.name, arguments: call.arguments))
            let output = try await toolGateway.executeToolCall(name: call.name, arguments: call.arguments)
            await onEvent(.toolCallCompleted(id: call.id, name: call.name, output: output))
            outputs.append(ToolCallOutput(id: call.id, output: output))
        }

        return outputs
    }
}

public struct PromptSessionResult: Sendable {
    public let finalAssistantText: String?
    public let finalTurn: PromptTurn
    public let promptTranscript: PromptTranscript
}

public enum PromptSessionRunnerError: Error, LocalizedError, Sendable {
    case toolIterationLimitExceeded(limit: Int)
    case missingContinuationToken

    public var errorDescription: String? {
        switch self {
        case let .toolIterationLimitExceeded(limit):
            return "Tool iteration limit exceeded (\(limit))."
        case .missingContinuationToken:
            return "Missing continuation token for tool call continuation."
        }
    }
}
