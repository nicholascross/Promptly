import Foundation

public struct Prompter {
    private let rawOutput: Bool
    private let tools: [any ExecutableTool]
    private let decoder = JSONDecoder()
    private let encoder = JSONEncoder()
    private let requestFactory: ChatRequestFactory

    public init(
        config: Config,
        rawOutput: Bool = false,
        modelOverride: String? = nil,
        tools: [any ExecutableTool] = []
    ) throws {
        self.rawOutput = rawOutput
        self.tools = tools

        requestFactory = ChatRequestFactory(
            chatCompletionURL: config.chatCompletionsURL,
            model: modelOverride ?? config.model,
            token: config.token,
            organizationId: config.organizationId,
            tools: tools,
            encoder: encoder
        )
    }

    /// Read standard input and stream chat with system prompts.
    /// - Parameters:
    ///   - systemPrompt: primary system prompt
    ///   - supplementarySystemPrompt: additional system prompt
    public func runChatStream(
        systemPrompt: String,
        supplementarySystemPrompt: String? = nil
    ) async throws {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let userInput = String(data: inputData, encoding: .utf8) ?? ""

        let messages = [
            ChatMessage(role: .system, content: .text(systemPrompt)),
            supplementarySystemPrompt.map { ChatMessage(role: .system, content: .text($0)) },
            ChatMessage(role: .user, content: .text(userInput))
        ].compactMap { $0 }

        try await runChatStream(messages: messages)
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
    ) async throws {
        var messages = initialMessages
        let callTool: (String, JSONValue) async throws -> JSONValue = { name, args in
            if let handler {
                return try await handler(name, args)
            }
            return try await self.tools.executeTool(name: name, arguments: args)
        }

        var replyPending = false
        repeat {
            let request = try requestFactory.makeRequest(
                messages: messages
            )
            let (stream, response) = try await URLSession.shared.bytes(for: request)

            guard
                let httpResponse = response as? HTTPURLResponse,
                200 ... 299 ~= httpResponse.statusCode
            else {
                throw PrompterError.invalidResponse(
                    statusCode: (response as? HTTPURLResponse)?.statusCode ?? -1
                )
            }

            if rawOutput {
                try await streamRawOutput(from: stream)
                return
            }

            let responseProcessor = ResponseProcessor()
            for try await line in stream.lines {
                let events = try await responseProcessor.process(line: line)

                for event in events {
                    switch event {
                    case let .content(text):
                        print(text, terminator: "")
                        fflush(stdout)
                    case let .toolCall(id, name, arguments):
                        await handleToolCall(
                            id: id,
                            functionName: name,
                            arguments: arguments,
                            callTool: callTool,
                            messages: &messages
                        )
                        replyPending = true
                    case .stop:
                        return
                    }
                }
            }
        } while replyPending
    }

    private func handleToolCall(
        id: String,
        functionName: String,
        arguments: JSONValue,
        callTool: (String, JSONValue) async throws -> JSONValue,
        messages: inout [ChatMessage]
    ) async {
        do {
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
                    role: .assistant,
                    content: .text("Error calling tool: \(error.localizedDescription)")
                )
            )
        }
    }

    private func streamRawOutput(from stream: URLSession.AsyncBytes) async throws {
        for try await line in stream.lines {
            print(line)
            fflush(stdout)
        }
    }
}

private struct ChatRequestFactory {
    private let chatCompletionsURL: URL
    private let model: String?
    private let token: String?
    private let organizationId: String?
    private let tools: [any ExecutableTool]
    private let encoder: JSONEncoder

    init(
        chatCompletionURL: URL,
        model: String?,
        token: String?,
        organizationId: String?,
        tools: [any ExecutableTool],
        encoder: JSONEncoder
    ) {
        chatCompletionsURL = chatCompletionURL
        self.model = model
        self.token = token
        self.organizationId = organizationId
        self.tools = tools
        self.encoder = encoder
    }

    func makeRequest(messages: [ChatMessage], toolChoice: ToolChoice = .auto) throws -> URLRequest {
        var request = URLRequest(url: chatCompletionsURL)

        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let org = organizationId {
            request.addValue(org, forHTTPHeaderField: "OpenAI-Organization")
        }

        let toolSpecs: [ToolSpec]? = tools.isEmpty ? nil : tools.map { tool in
            .init(function: .init(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            ))
        }

        let chatRequest = ChatRequest(
            model: model,
            messages: messages,
            stream: true,
            tools: toolSpecs,
            toolChoice: toolChoice
        )

        request.httpBody = try encoder.encode(chatRequest)

        return request
    }
}
