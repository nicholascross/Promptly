import Foundation
import PromptlyKitUtils

/// Public entry point for the run/event architecture.
public struct PromptRunCoordinator {
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

        let endpoint: any PromptEndpoint
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
                tools: tools,
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
                tools: tools,
                encoder: encoder
            )
            endpoint = ChatCompletionsPromptEndpoint(factory: factory, transport: transport, encoder: encoder)
        }

        runner = PromptRunExecutor(endpoint: endpoint, tools: tools)
    }

    public func run(
        messages: [PromptMessage],
        historyEntries: [PromptHistoryEntry]? = nil,
        resumeToken: String? = nil,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult {
        let resolvedHistoryEntries = historyEntries ?? messages.map { PromptHistoryEntry.message($0) }
        let entry: PromptEntry
        if let resumeToken {
            entry = .resume(
                context: .responses(previousResponseIdentifier: resumeToken),
                requestMessages: messages.asChatMessages()
            )
        } else {
            entry = .initial(messages: try resolvedHistoryEntries.asChatMessages())
        }

        return try await runner.run(
            entry: entry,
            initialHistoryEntries: resolvedHistoryEntries,
            onEvent: onEvent
        )
    }
}
