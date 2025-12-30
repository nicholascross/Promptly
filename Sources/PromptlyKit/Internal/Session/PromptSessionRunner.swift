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
        entry: PromptEntry,
        initialConversationEntries: [PromptConversationEntry] = [],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        let transcriptRecorder = PromptTranscriptRecorder(
            configuration: .init(toolOutputPolicy: .include)
        )
        let conversationRecorder = PromptConversationRecorder(
            initialEntries: initialConversationEntries
        )

        let eventHandler: @Sendable (PromptStreamEvent) async -> Void = { event in
            await transcriptRecorder.handle(event)
            await conversationRecorder.handle(event)
            await onEvent(event)
        }

        var turn = try await endpoint.prompt(entry: entry, onEvent: eventHandler)
        var latestResumeToken = turn.resumeToken ?? resumeToken(from: entry)

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

            guard let context = turn.context else {
                throw PromptSessionRunnerError.missingContinuationContext
            }

            turn = try await endpoint.prompt(
                entry: .toolCallResults(context: context, toolOutputs: toolOutputs),
                onEvent: eventHandler
            )
            if let resumeToken = turn.resumeToken {
                latestResumeToken = resumeToken
            }
        }

        let promptTranscript = await transcriptRecorder.finish()
        let conversationEntries = await conversationRecorder.finish()
        return PromptSessionResult(
            promptTranscript: promptTranscript,
            conversationEntries: conversationEntries,
            resumeToken: latestResumeToken
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

    private func resumeToken(from entry: PromptEntry) -> String? {
        guard case let .resume(context, _) = entry else {
            return nil
        }

        guard case let .responses(previousResponseIdentifier) = context else {
            return nil
        }

        return previousResponseIdentifier
    }
}
