import Foundation

struct PromptSessionRunner {
    struct Configuration: Sendable {
        let maximumToolIterations: Int

        init(maximumToolIterations: Int = 8) {
            self.maximumToolIterations = max(0, maximumToolIterations)
        }
    }

    private let endpoint: any PromptEndpoint
    private let tools: [any ExecutableTool]
    private let configuration: Configuration

    init(
        endpoint: any PromptEndpoint,
        tools: [any ExecutableTool],
        configuration: Configuration = Configuration()
    ) {
        self.endpoint = endpoint
        self.tools = tools
        self.configuration = configuration
    }

    func run(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        let transcriptRecorder = PromptTranscriptRecorder(
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

        let promptTranscript = await transcriptRecorder.finish(finalAssistantText: turn.finalAssistantText)
        return PromptSessionResult(
            finalAssistantText: turn.finalAssistantText,
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
            let output = try await tools.executeTool(name: call.name, arguments: call.arguments)
            await onEvent(.toolCallCompleted(id: call.id, name: call.name, output: output))
            outputs.append(ToolCallOutput(id: call.id, output: output))
        }

        return outputs
    }
}
