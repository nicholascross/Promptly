import Foundation

struct ResponsesAIClient: AIClient {
    private struct ToolInvocationOutput {
        let callId: String
        let output: JSONValue
    }

    private let client: ResponsesClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let outputHandler: AIClientFactory.OutputHandler
    private let toolOutputHandler: AIClientFactory.ToolOutputHandler
    private let toolCallHandler: AIClientFactory.ToolCallHandler?

    init(
        client: ResponsesClient,
        encoder: JSONEncoder,
        decoder: JSONDecoder,
        outputHandler: @escaping AIClientFactory.OutputHandler,
        toolOutputHandler: @escaping AIClientFactory.ToolOutputHandler,
        toolCallHandler: AIClientFactory.ToolCallHandler?
    ) {
        self.client = client
        self.encoder = encoder
        self.decoder = decoder
        self.outputHandler = outputHandler
        self.toolOutputHandler = toolOutputHandler
        self.toolCallHandler = toolCallHandler
    }

    func runStream(messages initialMessages: [ChatMessage]) async throws -> [ChatMessage] {
        var conversation = initialMessages
        var createResult = try await client.createResponse(
            items: initialMessages.map(RequestItem.message),
            previousResponseId: nil,
            onTextStream: outputHandler
        )

        var response = createResult.response
        var responsePending = true

        repeat {
            if
                let followUpItems = try await handleToolCalls(
                    toolCalls: response.toolCalls(),
                    outputHandler: outputHandler,
                    toolOutputHandler: toolOutputHandler,
                    toolCallHandler: toolCallHandler
                )
            {
                createResult = try await client.createResponse(
                    items: followUpItems,
                    previousResponseId: response.id,
                    onTextStream: outputHandler
                )

                response = createResult.response
                responsePending = true
                continue
            }

            switch response.status {
            case .completed:
                let reply = response.combinedOutputText()
                if let reply, !reply.isEmpty {
                    if createResult.didStream {
                        if !reply.hasSuffix("\n") {
                            outputHandler("\n")
                        }
                    } else {
                        outputHandler(reply + "\n")
                    }
                    let message = ChatMessage(role: .assistant, content: .text(reply))
                    conversation.append(message)
                }
                responsePending = false

            case .inProgress:
                try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
                response = try await client.retrieveResponse(id: response.id)

            case .requiresAction:
                throw PrompterError.invalidResponse(statusCode: -1)

            case .failed:
                let message = response.errorMessage ?? "The response failed."
                throw PrompterError.apiError(message)

            case .cancelled:
                throw PrompterError.apiError("The response was cancelled.")
            }
        } while responsePending

        return conversation
    }

    func complete(messages: [ChatMessage]) async throws -> String {
        var createResult = try await client.createResponse(items: messages.map(RequestItem.message))
        var response = createResult.response

        while true {
            switch response.status {
            case .completed:
                return response.combinedOutputText() ?? ""
            case .inProgress:
                try await Task.sleep(nanoseconds: 200_000_000)
                response = try await client.retrieveResponse(id: response.id)
                createResult = ResponseResult(response: response)
            case .requiresAction:
                throw PrompterError.apiError("Suggestion service received unexpected tool call")
            case .failed:
                throw PrompterError.apiError(response.errorMessage ?? "Suggestion service failed")
            case .cancelled:
                throw PrompterError.apiError("Suggestion service request cancelled")
            }
        }
    }

    private func handleToolCalls(
        toolCalls: [ToolCall],
        outputHandler: @escaping AIClientFactory.OutputHandler,
        toolOutputHandler: @escaping AIClientFactory.ToolOutputHandler,
        toolCallHandler: AIClientFactory.ToolCallHandler?
    ) async throws -> [RequestItem]? {
        guard !toolCalls.isEmpty else { return nil }

        let toolOutputs = try await executeToolCalls(
            toolCalls: toolCalls,
            toolOutputHandler: toolOutputHandler,
            toolCallHandler: toolCallHandler
        )

        return try toolOutputs.map { payload in
            let outputString = try encodeJSONValue(payload.output)
            return .functionOutput(
                FunctionCallOutputItem(callId: payload.callId, output: outputString)
            )
        }
    }

    private func executeToolCalls(
        toolCalls: [ToolCall],
        toolOutputHandler: @escaping AIClientFactory.ToolOutputHandler,
        toolCallHandler: AIClientFactory.ToolCallHandler?
    ) async throws -> [ToolInvocationOutput] {
        var outputs: [ToolInvocationOutput] = []

        for call in toolCalls {
            toolOutputHandler("Calling tool \(call.function.name)\n")
            let argumentsValue = decodeArguments(call.function.arguments)
            let result = try await invokeTool(
                name: call.function.name,
                arguments: argumentsValue,
                handler: toolCallHandler
            )
            outputs.append(ToolInvocationOutput(callId: call.callId, output: result))

            if let text = try? encodeJSONValue(result) {
                toolOutputHandler(text + "\n")
            }
        }

        return outputs
    }

    private func decodeArguments(_ raw: String) -> JSONValue {
        guard
            let data = raw.data(using: .utf8),
            let value = try? decoder.decode(JSONValue.self, from: data)
        else {
            return .string(raw)
        }
        return value
    }

    private func encodeJSONValue(_ value: JSONValue) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PrompterError.apiError("Failed to encode tool output.")
        }
        return text
    }

    private func invokeTool(
        name: String,
        arguments: JSONValue,
        handler: AIClientFactory.ToolCallHandler?
    ) async throws -> JSONValue {
        guard let handler else {
            throw PrompterError.apiError("Tool handler not configured.")
        }
        return try await handler(name, arguments)
    }
}
