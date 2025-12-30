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

    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        switch entry {
        case let .initial(messages):
            return try await runOnce(messages: messages, onEvent: onEvent)

        case .resume:
            // Chat Completions is stateless, so there is no server-side response identifier to resume from.
            // Resuming is only supported by the Responses endpoint using a previous response identifier.
            // The equivalent for Chat Completions is to send the full message history as new input.
            throw PromptError.resumeNotSupported

        case let .toolCallResults(context, toolOutputs):
            guard case let .chatCompletions(messages) = context else {
                throw PromptError.invalidConfiguration
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
    }

    private func runOnce(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        let request = try factory.makeRequest(messages: messages)
        let (lines, response) = try await transport.lineStream(for: request)

        guard
            let http = response as? HTTPURLResponse,
            200 ... 299 ~= http.statusCode
        else {
            throw PromptError.invalidResponse(statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1)
        }

        let processor = ChatCompletionsResponseProcessor()

        var toolCallRequest: ToolCallRequest?
        var assistantToolCallMessage: ChatMessage?

        for try await line in lines {
            let events = try await processor.process(line: line)
            for event in events {
                switch event {
                case let .content(text):
                    await onEvent(.assistantTextDelta(text))

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
                        context: nil,
                        toolCalls: [],
                        resumeToken: nil
                    )
                }
            }
        }

        if let toolCallRequest, let assistantToolCallMessage {
            return PromptTurn(
                context: .chatCompletions(messages: messages + [assistantToolCallMessage]),
                toolCalls: [toolCallRequest],
                resumeToken: nil
            )
        }

        return PromptTurn(
            context: nil,
            toolCalls: [],
            resumeToken: nil
        )
    }

    private func encodeJSONValue(_ value: JSONValue) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PromptError.apiError("Failed to encode tool output.")
        }
        return text
    }
}
