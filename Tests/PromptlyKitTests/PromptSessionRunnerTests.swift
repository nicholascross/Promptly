import Foundation
@testable import PromptlyKit
import Testing

struct PromptSessionRunnerTests {
    @Test
    func executesToolCallsAndContinuesUntilComplete() async throws {
        let endpoint = FakePromptEndpoint()
        let toolGateway = FakeToolGateway()
        let runner = PromptSessionRunner(endpoint: endpoint, toolGateway: toolGateway)

        let events = EventCollector()
        let result = try await runner.run(
            messages: [ChatMessage(role: .user, content: .text("hi"))],
            onEvent: { events.append($0) }
        )

        #expect(result.finalAssistantText == "Done.")

        let snapshot = events.snapshot()

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

private struct FakeToolGateway: ToolExecutionGateway {
    func executeToolCall(name: String, arguments: JSONValue) async throws -> JSONValue {
        .string("tool-output")
    }
}

private final class EventCollector: @unchecked Sendable {
    private let lock = NSLock()
    private var storage: [PromptStreamEvent] = []

    func append(_ event: PromptStreamEvent) {
        lock.lock()
        storage.append(event)
        lock.unlock()
    }

    func snapshot() -> [PromptStreamEvent] {
        lock.lock()
        let copy = storage
        lock.unlock()
        return copy
    }
}

private final class FakePromptEndpoint: PromptEndpoint {
    private var didStart = false

    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        didStart = true
        onEvent(.assistantTextDelta("Running..."))
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
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        #expect(didStart == true)
        #expect(toolOutputs.count == 1)
        onEvent(.assistantTextDelta("Done."))
        return PromptTurn(
            continuation: nil,
            toolCalls: [],
            finalAssistantText: "Done."
        )
    }
}
