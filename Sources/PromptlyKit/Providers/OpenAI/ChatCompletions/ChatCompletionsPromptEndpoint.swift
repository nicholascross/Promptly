import Foundation
import PromptlyKitUtils

struct ChatCompletionsPromptEndpoint: PromptEndpoint {
    private let factory: ChatCompletionsRequestFactory
    private let transport: any NetworkTransport
    private let encoder: JSONEncoder

    init(
        factory: ChatCompletionsRequestFactory,
        transport: any NetworkTransport,
        encoder: JSONEncoder
    ) {
        self.factory = factory
        self.transport = transport
        self.encoder = encoder
    }

    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        try await runOnce(messages: messages, onEvent: onEvent)
    }

    func continueSession(
        continuation: PromptContinuation,
        toolOutputs: [ToolCallOutput],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        guard case let .chatCompletions(messages) = continuation else {
            throw PrompterError.invalidConfiguration
        }

        var updatedMessages = messages
        for output in toolOutputs {
            let encoded = try encodeJSONValue(output.output)
            updatedMessages.append(
                ChatMessage(
                    role: .tool,
                    content: .text(encoded),
                    toolCallId: output.id
                )
            )
        }

        return try await runOnce(messages: updatedMessages, onEvent: onEvent)
    }

    private func runOnce(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        let request = try factory.makeRequest(messages: messages)
        let (lines, response) = try await transport.lineStream(for: request)

        guard
            let http = response as? HTTPURLResponse,
            200 ... 299 ~= http.statusCode
        else {
            throw PrompterError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let processor = ChatCompletionsResponseProcessor()

        var assistantContent = ""
        var toolCallRequest: ToolCallRequest?
        var assistantToolCallMessage: ChatMessage?

        for try await line in lines {
            let events = try await processor.process(line: line)
            for event in events {
                switch event {
                case let .content(text):
                    assistantContent += text
                    onEvent(.assistantTextDelta(text))

                case let .toolCall(id, name, args):
                    toolCallRequest = ToolCallRequest(id: id, name: name, arguments: args)

                    assistantToolCallMessage = ChatMessage(
                        role: .assistant,
                        id: id,
                        content: .empty,
                        toolCalls: [
                            ChatFunctionCall(
                                id: id,
                                function: try ChatFunction(name: name, arguments: args),
                                type: "function"
                            )
                        ]
                    )

                case .stop:
                    return PromptTurn(
                        continuation: nil,
                        toolCalls: [],
                        finalAssistantText: assistantContent
                    )
                }
            }
        }

        if let toolCallRequest, let assistantToolCallMessage {
            return PromptTurn(
                continuation: .chatCompletions(messages: messages + [assistantToolCallMessage]),
                toolCalls: [toolCallRequest],
                finalAssistantText: nil
            )
        }

        return PromptTurn(
            continuation: nil,
            toolCalls: [],
            finalAssistantText: assistantContent.isEmpty ? nil : assistantContent
        )
    }

    private func encodeJSONValue(_ value: JSONValue) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PrompterError.apiError("Failed to encode tool output.")
        }
        return text
    }
}
