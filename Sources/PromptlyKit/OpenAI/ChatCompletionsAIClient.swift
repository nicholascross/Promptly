import Foundation

struct ChatCompletionsAIClient: AIClient {
    private let factory: ChatCompletionsRequestFactory
    private let encoder: JSONEncoder
    private let outputHandler: AIClientFactory.OutputHandler
    private let toolOutputHandler: AIClientFactory.ToolOutputHandler
    private let toolCallHandler: AIClientFactory.ToolCallHandler?

    init(
        factory: ChatCompletionsRequestFactory,
        encoder: JSONEncoder,
        outputHandler: @escaping AIClientFactory.OutputHandler,
        toolOutputHandler: @escaping AIClientFactory.ToolOutputHandler,
        toolCallHandler: AIClientFactory.ToolCallHandler?
    ) {
        self.factory = factory
        self.encoder = encoder
        self.outputHandler = outputHandler
        self.toolOutputHandler = toolOutputHandler
        self.toolCallHandler = toolCallHandler
    }

    func runStream(messages initialMessages: [ChatMessage]) async throws -> [ChatMessage] {
        var messages = initialMessages

        while true {
            let request = try factory.makeRequest(messages: messages)
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard
                let httpResponse = response as? HTTPURLResponse,
                200 ... 299 ~= httpResponse.statusCode
            else {
                try await streamRawOutput(from: stream)
                throw PrompterError.invalidResponse(
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1
                )
            }

            var currentMessageContent = ""
            let processor = ChatCompletionsResponseProcessor()

            var replyMessages: [ChatMessage] = []

            for try await line in stream.lines {
                let events = try await processor.process(line: line)
                for event in events {
                    switch event {
                    case let .content(text):
                        currentMessageContent += text
                        outputHandler(text)
                    case let .toolCall(id, name, arguments):
                        replyMessages += await handleToolCall(
                            id: id,
                            functionName: name,
                            arguments: arguments
                        )
                    case .stop:
                        outputHandler("\n")
                        messages.append(
                            ChatMessage(
                                role: .assistant,
                                content: .text(currentMessageContent)
                            )
                        )
                    }
                }
            }

            messages.append(contentsOf: replyMessages)

            if replyMessages.isEmpty {
                return messages
            }
        }
    }

    func complete(messages: [ChatMessage]) async throws -> String {
        let request = try factory.makeRequest(messages: messages, toolChoice: .none)
        let (stream, response) = try await URLSession.shared.bytes(for: request)

        guard let http = response as? HTTPURLResponse, 200 ... 299 ~= http.statusCode else {
            return ""
        }

        return try await ChatCompletionsResponseProcessor().collectContent(from: stream)
    }

    private func handleToolCall(
        id: String,
        functionName: String,
        arguments: JSONValue
    ) async -> [ChatMessage] {
        var messages: [ChatMessage] = []

        do {
            toolOutputHandler("Calling tool \(functionName)\n")
            let functionCall = try ChatFunctionCall(
                id: id,
                function: ChatFunction(name: functionName, arguments: arguments),
                type: "function"
            )

            messages.append(
                ChatMessage(
                    role: .assistant,
                    id: id,
                    content: .empty,
                    toolCalls: [functionCall]
                )
            )

            let result = try await invokeTool(name: functionName, arguments: arguments)
            let json = try encodeJSONValue(result)
            toolOutputHandler(json + "\n")

            messages.append(
                ChatMessage(
                    role: .tool,
                    content: .text(json),
                    toolCallId: id
                )
            )
        } catch {
            let message = "Error calling tool: \(error.localizedDescription)"
            toolOutputHandler(message + "\n")
            messages.append(
                ChatMessage(
                    role: .tool,
                    content: .text(message),
                    toolCallId: id
                )
            )
        }

        return messages
    }

    private func encodeJSONValue(_ value: JSONValue) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PrompterError.apiError("Failed to encode tool output.")
        }
        return text
    }

    private func streamRawOutput(
        from stream: URLSession.AsyncBytes
    ) async throws {
        for try await line in stream.lines {
            outputHandler(line + "\n")
        }
    }

    private func invokeTool(
        name: String,
        arguments: JSONValue
    ) async throws -> JSONValue {
        guard let toolCallHandler else {
            throw PrompterError.apiError("Tool handler not configured.")
        }
        return try await toolCallHandler(name, arguments)
    }
}
