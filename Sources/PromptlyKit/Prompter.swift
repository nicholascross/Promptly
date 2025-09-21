import Foundation

public struct Prompter {
    private let tools: [any ExecutableTool]
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let requestFactory: ChatRequestFactory

    /// Handler for streaming output strings (may include newline characters).
    public typealias OutputHandler = (String) -> Void
    /// Handler for streaming output from tool calls.
    public typealias ToolOutputHandler = OutputHandler
    private let output: OutputHandler
    private let toolOutput: ToolOutputHandler

    /// Result of a single streaming iteration.
    private enum StreamResult {
        case finish([ChatMessage])
        case `continue`([ChatMessage])
    }

    /// Create a new Prompter.
    ///
    /// - Parameters:
    ///   - config: Configuration for OpenAI API.
    ///   - modelOverride: Optional model name override.
    ///   - tools: List of executable tools available to the prompter.
    ///   - output: Handler for streaming output; defaults to standard output.
    ///   - toolOutput: Handler for streaming tool output; defaults to standard output.
    public init(
        config: Config,
        modelOverride: String? = nil,
        tools: [any ExecutableTool] = [],
        output: @escaping OutputHandler = { stream in fputs(stream, stdout); fflush(stdout) },
        toolOutput: @escaping ToolOutputHandler = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws {
        self.tools = tools
        self.output = output
        self.toolOutput = toolOutput

        requestFactory = ChatRequestFactory(
            chatCompletionURL: config.chatCompletionsURL,
            model: config.resolveModel(override: modelOverride),
            token: config.token,
            organizationId: config.organizationId,
            tools: tools,
            encoder: encoder
        )
    }

    /// Stream a chat, automatically pausing for tool calls,
    /// executing the tool, and resuming the assistant’s response.
    /// - Parameters:
    ///   - messages: the conversation so far
    ///   - onToolCall: optional override for handling tool calls; if nil, uses the tools registered
    /// at initialization
    public func runChatStream(
        messages initialMessages: [ChatMessage],
        onToolCall handler: ((String, JSONValue) async throws -> JSONValue)? = nil
    ) async throws -> [ChatMessage] {
        var messages = initialMessages
        let callTool: (String, JSONValue) async throws -> JSONValue = { name, args in
            if let handler {
                return try await handler(name, args)
            }
            return try await self.tools.executeTool(name: name, arguments: args)
        }

        while true {
            let result = try await processStreamOnce(messages: messages, callTool: callTool)
            switch result {
            case .finish(let finalMessages):
                return finalMessages
            case .continue(let nextMessages):
                messages = nextMessages
            }
        }
    }

    private func processStreamOnce(
        messages initialMessages: [ChatMessage],
        callTool: (String, JSONValue) async throws -> JSONValue
    ) async throws -> StreamResult {
        var messages = initialMessages
        let request = try requestFactory.makeRequest(messages: messages)
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
        let responseProcessor = ResponseProcessor()

        var replyMessages: [ChatMessage] = []

        for try await line in stream.lines {
            let events = try await responseProcessor.process(line: line)
            for event in events {
                switch event {
                case let .content(text):
                    currentMessageContent += text
                    output(text)
                case let .toolCall(id, name, arguments):
                    let functionCall = try ChatFunctionCall(
                        id: id,
                        function: ChatFunction(name: name, arguments: arguments),
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

                    replyMessages += await handleToolCall(
                        id: id,
                        functionName: name,
                        arguments: arguments,
                        callTool: callTool
                    )
                case .stop:
                    output("\n")
                    messages.append(
                        ChatMessage(role: .assistant, content: .text(currentMessageContent))
                    )
                }
            }
        }

        messages.append(contentsOf: replyMessages)

        return !replyMessages.isEmpty ? .continue(messages) : .finish(messages)
    }

    private func handleToolCall(
        id: String,
        functionName: String,
        arguments: JSONValue,
        callTool: (String, JSONValue) async throws -> JSONValue,
    ) async -> [ChatMessage] {
        var messages = [ChatMessage]()
        do {
            let result = try await callTool(functionName, arguments)
            let data = try encoder.encode(result)
            let json = String(data: data, encoding: .utf8) ?? ""
            let block = ContentBlock(type: "text", text: json)

            messages.append(
                ChatMessage(
                    role: .tool,
                    content: .blocks([block]),
                    toolCallId: id
                )
            )
        } catch {
            messages.append(
                ChatMessage(
                    role: .tool,
                    content: .text("Error calling tool: \(error.localizedDescription)"),
                    toolCallId: id
                )
            )
        }

        return messages
    }

    private func streamRawOutput(from stream: URLSession.AsyncBytes) async throws {
        for try await line in stream.lines {
            output(line + "\n")
        }
    }
}
