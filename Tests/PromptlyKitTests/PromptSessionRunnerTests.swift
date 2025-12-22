import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct PromptSessionRunnerTests {
    @Test
    func executesToolCallsAndContinuesUntilComplete() async throws {
        let endpoint = FakePromptEndpoint()
        let tool = StaticTool(output: .string("tool-output"))
        let runner = PromptSessionRunner(endpoint: endpoint, tools: [tool])

        let events = EventCollector()
        let result = try await runner.run(
            messages: [ChatMessage(role: .user, content: .text("hi"))],
            onEvent: { event in
                await events.append(event)
            }
        )

        #expect(result.finalAssistantText == "Done.")

        let snapshot = await events.snapshot()

        #expect(snapshot.contains { event in
            if case .assistantTextDelta = event { return true }
            return false
        })

        #expect(snapshot.contains { event in
            if case let .toolCallRequested(id, name, _) = event {
                return id == "call_1" && name == "Echo"
            }
            return false
        })

        #expect(snapshot.contains { event in
            if case let .toolCallCompleted(id, name, output) = event {
                guard id == "call_1", name == "Echo" else { return false }
                if case let .string(text) = output {
                    return text == "tool-output"
                }
            }
            return false
        })
    }
}

private struct StaticTool: ExecutableTool {
    let output: JSONValue

    let name: String = "Echo"
    let description: String = "Static tool for testing."
    let parameters: JSONSchema = .object(requiredProperties: [:], optionalProperties: [:], description: nil)

    func execute(arguments: JSONValue) async throws -> JSONValue {
        output
    }
}

private actor EventCollector {
    private var storage: [PromptStreamEvent] = []

    func append(_ event: PromptStreamEvent) {
        storage.append(event)
    }

    func snapshot() -> [PromptStreamEvent] {
        storage
    }
}

private final class FakePromptEndpoint: PromptEndpoint {
    private var didStart = false

    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        didStart = true
        await onEvent(.assistantTextDelta("Running..."))
        return PromptTurn(
            continuation: .responses(previousResponseId: "r1"),
            toolCalls: [
                ToolCallRequest(
                    id: "call_1",
                    name: "Echo",
                    arguments: .object(["text": .string("hello")])
                )
            ],
            finalAssistantText: nil
        )
    }

    func continueSession(
        continuation: PromptContinuation,
        toolOutputs: [ToolCallOutput],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        #expect(didStart == true)
        #expect(toolOutputs.count == 1)
        await onEvent(.assistantTextDelta("Done."))
        return PromptTurn(
            continuation: nil,
            toolCalls: [],
            finalAssistantText: "Done."
        )
    }
}
