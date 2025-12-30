import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct PromptRunExecutorTranscriptIntegrationTests {
    @Test
    func includesAssistantTextAfterToolCalls() async throws {
        let endpoint = FinalTextOnlyAfterToolCallEndpoint()
        let tool = StaticTool(output: .string("tool-output"))
        let runner = PromptRunExecutor(endpoint: endpoint, tools: [tool])

        let result = try await runner.run(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { _ in }
        )
        let conversationEntries = result.conversationEntries

        #expect(conversationEntries.count == 4)

        if case let .text(message) = conversationEntries[0].content {
            #expect(conversationEntries[0].role == .assistant)
            #expect(message == "Preparing...")
        } else {
            Issue.record("Expected assistant message entry.")
        }

        guard let toolCalls = conversationEntries[1].toolCalls,
              let toolCall = toolCalls.first else {
            Issue.record("Expected assistant tool call entry.")
            return
        }
        #expect(conversationEntries[1].role == .assistant)
        #expect(toolCall.id == "call_1")
        #expect(toolCall.name == "Echo")
        if case let .object(object) = toolCall.arguments {
            expectString(object["text"], equals: "hello")
        } else {
            Issue.record("Expected tool call arguments object.")
        }

        #expect(conversationEntries[2].role == .tool)
        #expect(conversationEntries[2].toolCallId == "call_1")
        if case let .json(output) = conversationEntries[2].content {
            expectString(output, equals: "tool-output")
        } else {
            Issue.record("Expected tool output content.")
        }

        if case let .text(message) = conversationEntries[3].content {
            #expect(conversationEntries[3].role == .assistant)
            #expect(message == "All done.")
        } else {
            Issue.record("Expected final assistant message entry.")
        }
    }

    @Test
    func doesNotDuplicateAssistantTextWhenStreamed() async throws {
        let endpoint = StreamedFinalTextEndpoint()
        let tool = StaticTool(output: .string("tool-output"))
        let runner = PromptRunExecutor(endpoint: endpoint, tools: [tool])

        let result = try await runner.run(
            entry: .initial(messages: [ChatMessage(role: .user, content: .text("hi"))]),
            onEvent: { _ in }
        )
        let assistantMessages = result.conversationEntries.compactMap { entry -> String? in
            guard entry.role == .assistant else { return nil }
            guard case let .text(message) = entry.content else { return nil }
            return message
        }

        #expect(assistantMessages == ["Preparing...", "All done."])
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

private final class FinalTextOnlyAfterToolCallEndpoint: PromptTurnEndpoint {
    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        switch entry {
        case .initial:
            await onEvent(.assistantTextDelta("Preparing..."))
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
        case .toolCallResults:
            await onEvent(.assistantTextDelta("All done."))
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

private final class StreamedFinalTextEndpoint: PromptTurnEndpoint {
    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        switch entry {
        case .initial:
            await onEvent(.assistantTextDelta("Preparing..."))
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
        case .toolCallResults:
            await onEvent(.assistantTextDelta("All done."))
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
