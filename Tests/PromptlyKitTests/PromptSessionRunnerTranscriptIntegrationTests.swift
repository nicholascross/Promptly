import Foundation
@testable import PromptlyKit
import Testing

struct PromptSessionRunnerTranscriptIntegrationTests {
    @Test
    func includesFinalAssistantTextWhenNotStreamedAfterToolCalls() async throws {
        let endpoint = FinalTextOnlyAfterToolCallEndpoint()
        let toolGateway = StaticToolGateway(output: .string("tool-output"))
        let runner = PromptSessionRunner(endpoint: endpoint, toolGateway: toolGateway)

        let events = EventCollector()

        let result = try await runner.run(
            messages: [ChatMessage(role: .user, content: .text("hi"))],
            onEvent: { event in
                events.append(event)
            }
        )

        var transcriptAccumulator = PromptTranscriptAccumulator(
            configuration: .init(toolOutputPolicy: .include)
        )
        for event in events.snapshot() {
            transcriptAccumulator.handle(event)
        }

        let transcript = transcriptAccumulator.finish(finalAssistantText: result.finalAssistantText)

        #expect(transcript.entries.count == 3)

        if case let .assistant(message) = transcript.entries[0] {
            #expect(message == "Preparing...")
        } else {
            Issue.record("Expected assistant message entry.")
        }

        if case let .toolCall(id, name, arguments, output) = transcript.entries[1] {
            #expect(id == "call_1")
            #expect(name == "Echo")
            if case let .object(object)? = arguments {
                expectString(object["text"], equals: "hello")
            } else {
                Issue.record("Expected tool call arguments object.")
            }
            expectString(output, equals: "tool-output")
        } else {
            Issue.record("Expected tool call entry.")
        }

        if case let .assistant(message) = transcript.entries[2] {
            #expect(message == "All done.")
        } else {
            Issue.record("Expected final assistant message entry.")
        }
    }

    @Test
    func doesNotDuplicateFinalAssistantTextWhenAlreadyStreamed() async throws {
        let endpoint = StreamedFinalTextEndpoint()
        let toolGateway = StaticToolGateway(output: .string("tool-output"))
        let runner = PromptSessionRunner(endpoint: endpoint, toolGateway: toolGateway)

        let events = EventCollector()

        let result = try await runner.run(
            messages: [ChatMessage(role: .user, content: .text("hi"))],
            onEvent: { event in
                events.append(event)
            }
        )

        var transcriptAccumulator = PromptTranscriptAccumulator(
            configuration: .init(toolOutputPolicy: .include)
        )
        for event in events.snapshot() {
            transcriptAccumulator.handle(event)
        }

        let transcript = transcriptAccumulator.finish(finalAssistantText: result.finalAssistantText)

        let assistantMessages = transcript.entries.compactMap { entry -> String? in
            if case let .assistant(message) = entry { return message }
            return nil
        }

        #expect(assistantMessages == ["Preparing...", "All done."])
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

private struct StaticToolGateway: ToolExecutionGateway {
    let output: JSONValue

    func executeToolCall(name: String, arguments: JSONValue) async throws -> JSONValue {
        output
    }
}

private final class FinalTextOnlyAfterToolCallEndpoint: PromptEndpoint {
    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        onEvent(.assistantTextDelta("Preparing..."))
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
        PromptTurn(
            continuation: nil,
            toolCalls: [],
            finalAssistantText: "All done."
        )
    }
}

private final class StreamedFinalTextEndpoint: PromptEndpoint {
    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        onEvent(.assistantTextDelta("Preparing..."))
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
        onEvent(.assistantTextDelta("All done."))
        return PromptTurn(
            continuation: nil,
            toolCalls: [],
            finalAssistantText: "All done."
        )
    }
}
