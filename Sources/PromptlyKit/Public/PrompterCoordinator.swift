import Foundation
import PromptlyKitUtils

/// Public entry point for the session/event architecture.
public struct PrompterCoordinator {
    private let runner: PromptSessionRunner

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

        let endpoint: any PromptEndpoint
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
            let client = ResponsesClient(factory: factory, decoder: decoder, transport: transport)
            endpoint = ResponsesPromptEndpoint(client: client, encoder: encoder, decoder: decoder)

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
            endpoint = ChatCompletionsPromptEndpoint(factory: factory, transport: transport, encoder: encoder)
        }

        runner = PromptSessionRunner(endpoint: endpoint, tools: tools)
    }

    public func run(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        try await runner.run(messages: messages, onEvent: onEvent)
    }
}
