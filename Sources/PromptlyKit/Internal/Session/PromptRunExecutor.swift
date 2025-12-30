import Foundation

struct PromptRunExecutor {
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
        initialHistoryEntries: [PromptHistoryEntry] = [],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult {
        let transcriptRecorder = PromptTranscriptRecorder(
            configuration: .init(toolOutputPolicy: .include)
        )
        let historyRecorder = PromptHistoryRecorder(
            initialEntries: initialHistoryEntries
        )

        let eventHandler: @Sendable (PromptStreamEvent) async -> Void = { event in
            await transcriptRecorder.handle(event)
            await historyRecorder.handle(event)
            await onEvent(event)
        }

        var turn = try await endpoint.prompt(entry: entry, onEvent: eventHandler)
        var latestResumeToken = turn.resumeToken ?? resumeToken(from: entry)

        var toolIterations = 0
        while !turn.toolCalls.isEmpty {
            toolIterations += 1
            if toolIterations > configuration.maximumToolIterations {
                throw PromptRunExecutorError.toolIterationLimitExceeded(limit: configuration.maximumToolIterations)
            }

            let toolOutputs = try await executeTools(
                toolCalls: turn.toolCalls,
                onEvent: eventHandler
            )

            guard let context = turn.context else {
                throw PromptRunExecutorError.missingContinuationContext
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
        let historyEntries = await historyRecorder.finish()
        return PromptRunResult(
            promptTranscript: promptTranscript,
            historyEntries: historyEntries,
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
