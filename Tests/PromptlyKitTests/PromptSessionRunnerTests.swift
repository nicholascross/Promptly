import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct PromptRunExecutorTests {
    @Test
    func executesToolCallsAndContinuesUntilComplete() async throws {
        let endpoint = FakePromptEndpoint()
        let tool = StaticTool(output: .string("tool-output"))
        let runner = PromptRunExecutor(endpoint: endpoint, tools: [tool])

        let events = EventCollector()
        let result = try await runner.run(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { event in
                await events.append(event)
            }
        )

        let assistantMessages = result.conversationEntries.compactMap { entry -> String? in
            guard entry.role == .assistant else { return nil }
            guard case let .text(message) = entry.content else { return nil }
            return message
        }
        #expect(assistantMessages.last == "Done.")

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

private final class FakePromptEndpoint: PromptTurnEndpoint {
    private var didStart = false

    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        switch entry {
        case .initial:
            didStart = true
            await onEvent(.assistantTextDelta("Running..."))
            return PromptTurn(
                context: .responses(previousResponseIdentifier: "r1"),
                toolCalls: [
                    ToolCallRequest(
                        id: "call_1",
                        name: "Echo",
                        arguments: .object(["text": .string("hello")])
                    )
                ],
                resumeToken: nil
            )
        case let .toolCallResults(context, toolOutputs):
            #expect(didStart == true)
            #expect(toolOutputs.count == 1)
            guard case .responses = context else {
                Issue.record("Expected responses context for tool continuation.")
                return PromptTurn(context: nil, toolCalls: [], resumeToken: nil)
            }
            await onEvent(.assistantTextDelta("Done."))
            return PromptTurn(
                context: nil,
                toolCalls: [],
                resumeToken: nil
            )
        case .resume:
            Issue.record("Resume not expected in this test.")
            return PromptTurn(context: nil, toolCalls: [], resumeToken: nil)
        }
    }
}
