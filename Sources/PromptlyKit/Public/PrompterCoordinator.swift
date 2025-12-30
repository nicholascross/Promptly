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
        messages: [PromptMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        let conversationEntries = messages.map { PromptConversationEntry.message($0) }
        return try await run(
            requestMessages: messages,
            conversationEntries: conversationEntries,
            resumeToken: nil,
            onEvent: onEvent
        )
    }

    public func run(
        requestMessages: [PromptMessage],
        conversationEntries: [PromptConversationEntry],
        resumeToken: String?,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptSessionResult {
        let entry: PromptEntry
        if let resumeToken {
            entry = .resume(
                context: .responses(previousResponseIdentifier: resumeToken),
                requestMessages: requestMessages.asChatMessages()
            )
        } else {
            entry = .initial(messages: try conversationEntries.asChatMessages())
        }

        return try await runner.run(
            entry: entry,
            initialConversationEntries: conversationEntries,
            onEvent: onEvent
        )
    }
}
