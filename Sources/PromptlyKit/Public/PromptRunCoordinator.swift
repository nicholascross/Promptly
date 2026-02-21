import Foundation
import PromptlyKitCommunication
import PromptlyOpenAIClient
import PromptlyKitUtils

/// Public entry point for coordinating prompt runs and stream events.
public struct PromptRunCoordinator: PromptEndpoint {
    private let runner: PromptRunExecutor

    public init(
        config: Config,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        tools: [any ExecutableTool] = [],
        transport: any NetworkTransport = URLSessionNetworkTransport()
    ) throws {
        let model = config.resolveModel(override: modelOverride)
        let api = apiOverride ?? config.api

        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        let toolDefinitions = tools.map { tool in
            OpenAIToolDefinition(
                name: tool.name,
                description: tool.description,
                parameters: tool.parameters
            )
        }

        let endpoint: any PromptTurnEndpoint
        switch api {
        case .responses:
            guard let responsesURL = config.responsesURL else {
                throw PromptError.invalidConfiguration
            }
            let factory = ResponsesRequestFactory(
                responsesURL: responsesURL,
                model: model,
                token: config.token,
                organizationId: config.organizationId,
                tools: toolDefinitions,
                encoder: encoder
            )
            let client = ResponsesClient(factory: factory, decoder: decoder, transport: transport)
            endpoint = ResponsesPromptEndpoint(client: client, encoder: encoder, decoder: decoder)

        case .chatCompletions:
            guard let chatURL = config.chatCompletionsURL else {
                throw PromptError.invalidConfiguration
            }
            let factory = ChatCompletionsRequestFactory(
                chatCompletionURL: chatURL,
                model: model,
                token: config.token,
                organizationId: config.organizationId,
                tools: toolDefinitions,
                encoder: encoder
            )
            endpoint = ChatCompletionsPromptEndpoint(factory: factory, transport: transport, encoder: encoder)
        }

        runner = PromptRunExecutor(endpoint: endpoint, tools: tools)
    }

    public func prompt(
        context: PromptRunContext,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult {
        switch context {
        case let .messages(entries):
            let messages = try entries.asChatMessages()
            return try await runner.run(
                entry: .initial(messages: messages),
                onEvent: onEvent
            )
        case let .resume(resumeToken, requestMessages):
            return try await runner.run(
                entry: .resume(
                    context: .responses(previousResponseIdentifier: resumeToken),
                    requestMessages: try requestMessages.asChatMessages()
                ),
                onEvent: onEvent
            )
        }
    }
}
