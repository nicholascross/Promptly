import Darwin
import Foundation

public struct Prompter: AIClient {
    private let client: any AIClient

    /// Handler for streaming output strings (may include newline characters).
    public typealias OutputHandler = (String) -> Void
    /// Handler for streaming output from tool calls.
    public typealias ToolOutputHandler = OutputHandler

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
        apiOverride: Config.API? = nil,
        tools: [any ExecutableTool] = [],
        output: @escaping OutputHandler = { stream in fputs(stream, stdout); fflush(stdout) },
        toolOutput: @escaping ToolOutputHandler = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws {
        let model = config.resolveModel(override: modelOverride)
        let api = apiOverride ?? config.api

        let toolCallHandler: AIClientFactory.ToolCallHandler? = tools.isEmpty ? nil : { name, args in
            for tool in tools where tool.name == name {
                return try await tool.execute(arguments: args)
            }
            return .null
        }

        self.client = try AIClientFactory.makeClient(
            config: config,
            api: api,
            model: model,
            tools: tools,
            outputHandler: output,
            toolOutputHandler: toolOutput,
            toolCallHandler: toolCallHandler
        )
    }

    /// Send messages to the model, handling tool calls when requested.
    public func runStream(messages: [ChatMessage]) async throws -> [ChatMessage] {
        try await client.runStream(messages: messages)
    }

    public func complete(messages: [ChatMessage]) async throws -> String {
        try await client.complete(messages: messages)
    }

    public func runChatStream(
        messages initialMessages: [ChatMessage]
    ) async throws -> [ChatMessage] {
        try await runStream(messages: initialMessages)
    }
}
