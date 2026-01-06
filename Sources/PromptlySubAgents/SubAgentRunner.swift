import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils

private struct PromptRunCoordinatorAdapter: PromptEndpoint {
    private let coordinator: PromptRunCoordinator

    init(
        configuration: Config,
        tools: [any ExecutableTool],
        modelOverride: String?,
        apiOverride: Config.API?
    ) throws {
        coordinator = try PromptRunCoordinator(
            config: configuration,
            modelOverride: modelOverride,
            apiOverride: apiOverride,
            tools: tools
        )
    }

    func prompt(
        context: PromptRunContext,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult {
        try await coordinator.prompt(
            context: context,
            onEvent: onEvent
        )
    }
}

struct SubAgentRunner: Sendable {
    private static let maximumReturnPayloadAttempts = 2

    private let configuration: SubAgentConfiguration
    private let toolSettings: SubAgentToolSettings
    private let logDirectoryURL: URL
    private let toolOutput: @Sendable (String) -> Void
    private let coordinatorFactory: @Sendable ([any ExecutableTool]) throws -> any PromptEndpoint
    private let fileManager: FileManagerProtocol
    private let sessionState: SubAgentSessionState
    private let apiOverride: Config.API?

    init(
        configuration: SubAgentConfiguration,
        toolSettings: SubAgentToolSettings,
        logDirectoryURL: URL,
        toolOutput: @Sendable @escaping (String) -> Void,
        fileManager: FileManagerProtocol,
        sessionState: SubAgentSessionState,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        coordinatorFactory: (@Sendable ([any ExecutableTool]) throws -> any PromptEndpoint)? = nil
    ) {
        self.configuration = configuration
        self.toolSettings = toolSettings
        self.logDirectoryURL = logDirectoryURL.standardizedFileURL
        self.toolOutput = toolOutput
        self.fileManager = fileManager
        self.sessionState = sessionState
        self.apiOverride = apiOverride
        let resolvedCoordinatorFactory = coordinatorFactory ?? { tools in
            try PromptRunCoordinatorAdapter(
                configuration: configuration.configuration,
                tools: tools,
                modelOverride: modelOverride,
                apiOverride: apiOverride
            )
        }
        self.coordinatorFactory = resolvedCoordinatorFactory
    }

    func run(request: SubAgentToolRequest) async throws -> JSONValue {
        let transcriptLogger = try? SubAgentTranscriptLogger(
            logsDirectoryURL: logDirectoryURL,
            fileManager: fileManager
        )
        var didFinishLogging = false
        let promptAssembler = SubAgentPromptAssembler(
            configuration: configuration,
            sessionState: sessionState,
            apiOverride: apiOverride
        )
        let payloadHandler = SubAgentReturnPayloadHandler()

        let systemMessage = promptAssembler.makeSystemMessage()
        let userMessage = promptAssembler.makeUserMessage(for: request)
        let reminderMessage = promptAssembler.makeReturnPayloadReminderMessage()
        let resumeIdentifier = promptAssembler.normalizeResumeIdentifier(request.resumeId)
        let resumeEntry = try await promptAssembler.resolveResumeEntry(for: resumeIdentifier)
        let initialContext = try promptAssembler.initialContext(
            systemMessage: systemMessage,
            userMessage: userMessage,
            resumeEntry: resumeEntry
        )
        let context = initialContext.context
        let effectiveApi = initialContext.effectiveApi
        let toolBuilder = SubAgentToolBuilder(
            configuration: configuration,
            toolSettings: toolSettings,
            fileManager: fileManager,
            toolOutput: toolOutput
        )
        let tools = try toolBuilder.makeTools(transcriptLogger: transcriptLogger)
        let coordinator = try coordinatorFactory(tools)

        do {
            var currentContext = context
            var attempt = 0
            var combinedConversationEntries: [PromptMessage] = []
            var latestResumeToken = resumeEntry?.resumeToken
            var payload: JSONValue?

            while payload == nil {
                attempt += 1
                let result = try await coordinator.prompt(
                    context: currentContext,
                    onEvent: { event in
                        await transcriptLogger?.handle(event: event)
                    }
                )
                if let resumeToken = result.resumeToken {
                    latestResumeToken = resumeToken
                }
                combinedConversationEntries.append(contentsOf: result.conversationEntries)

                if let returnedPayload = payloadHandler.extractReturnPayload(
                    from: result.conversationEntries
                ) {
                    payload = returnedPayload
                    break
                }

                if attempt >= Self.maximumReturnPayloadAttempts {
                    break
                }

                let followUpMessages = promptAssembler.chatMessages(
                    systemMessage: systemMessage,
                    userMessage: userMessage,
                    resumeEntry: resumeEntry,
                    conversationEntries: combinedConversationEntries
                )
                currentContext = promptAssembler.followUpContext(
                    effectiveApi: effectiveApi,
                    resumeToken: latestResumeToken,
                    chatMessages: followUpMessages,
                    reminderMessage: reminderMessage
                )
            }

            let resolution = payloadHandler.resolvePayload(
                candidate: payload,
                conversationEntries: combinedConversationEntries
            )
            let didUseMissingReturnPayload = resolution.didUseFallback

            var payloadWithLogPath = payloadHandler.attachLogPath(
                to: resolution.payload,
                logPath: transcriptLogger?.logPath
            )
            if resolution.needsFollowUp {
                let mergedConversationEntries: [PromptMessage]
                if let resumeEntry, effectiveApi == .responses {
                    mergedConversationEntries = resumeEntry.conversationEntries + combinedConversationEntries
                } else {
                    mergedConversationEntries = combinedConversationEntries
                }
                let storedResumeEntry = await sessionState.storeResumeEntry(
                    resumeId: resumeIdentifier,
                    agentName: configuration.definition.name,
                    conversationEntries: mergedConversationEntries,
                    resumeToken: latestResumeToken
                )
                payloadWithLogPath = payloadHandler.attachResumeIdentifier(
                    storedResumeEntry.resumeId,
                    to: payloadWithLogPath
                )
            } else {
                payloadWithLogPath = payloadHandler.removeResumeIdentifier(
                    from: payloadWithLogPath
                )
            }
            await transcriptLogger?.recordReturnPayload(payloadWithLogPath)
            let status = didUseMissingReturnPayload ? "missing_return_payload" : "completed"
            await transcriptLogger?.finish(status: status, error: nil)
            didFinishLogging = true

            return payloadWithLogPath
        } catch {
            if !didFinishLogging {
                await transcriptLogger?.finish(status: "failed", error: error)
            }
            throw error
        }
    }

}
