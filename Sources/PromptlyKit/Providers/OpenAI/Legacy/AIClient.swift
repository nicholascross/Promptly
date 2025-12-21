import Foundation
import PromptlyKitUtils

public protocol AIClient {
    func runStream(messages: [ChatMessage]) async throws -> [ChatMessage]

    func complete(messages: [ChatMessage]) async throws -> String
}

public extension AIClient {
    /// Convenience wrapper that mirrors the legacy Prompter API while delegating to `runStream`.
    func runChatStream(messages: [ChatMessage]) async throws -> [ChatMessage] {
        try await runStream(messages: messages)
    }
}

enum AIClientFactory {
    typealias OutputHandler = (String) -> Void
    typealias ToolOutputHandler = OutputHandler
    typealias ToolCallHandler = (String, JSONValue) async throws -> JSONValue

    static func makeClient(
        config: Config,
        api: Config.API,
        model: String?,
        tools: [any ExecutableTool],
        outputHandler: @escaping OutputHandler,
        toolOutputHandler: @escaping ToolOutputHandler,
        toolCallHandler: ToolCallHandler?
    ) throws -> any AIClient {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()

        switch api {
        case .responses:
            guard let responsesURL = config.responsesURL else {
                throw PrompterError.invalidConfiguration
            }
            let factory = ResponsesRequestFactory(
                responsesURL: responsesURL,
                model: model,
                token: config.token,
                organizationId: config.organizationId,
                tools: tools,
                encoder: encoder
            )
            let client = ResponsesClient(factory: factory, decoder: decoder)
            return ResponsesAIClient(
                client: client,
                encoder: encoder,
                decoder: decoder,
                outputHandler: outputHandler,
                toolOutputHandler: toolOutputHandler,
                toolCallHandler: toolCallHandler
            )

        case .chatCompletions:
            guard let chatURL = config.chatCompletionsURL else {
                throw PrompterError.invalidConfiguration
            }
            let factory = ChatCompletionsRequestFactory(
                chatCompletionURL: chatURL,
                model: model,
                token: config.token,
                organizationId: config.organizationId,
                tools: tools,
                encoder: encoder
            )
            return ChatCompletionsAIClient(
                factory: factory,
                encoder: encoder,
                outputHandler: outputHandler,
                toolOutputHandler: toolOutputHandler,
                toolCallHandler: toolCallHandler
            )
        }
    }
}
