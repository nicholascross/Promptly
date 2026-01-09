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
        let transcriptFinalizer = SubAgentTranscriptFinalizer(
            logger: transcriptLogger
        )
        let toolBuilder = SubAgentToolBuilder(
            configuration: configuration,
            toolSettings: toolSettings,
            fileManager: fileManager,
            toolOutput: toolOutput
        )
        let tools = try toolBuilder.makeTools(transcriptLogger: transcriptLogger)
        let coordinator = try coordinatorFactory(tools)

        do {
            let promptAssembler = SubAgentPromptAssembler(
                configuration: configuration,
                sessionState: sessionState,
                apiOverride: apiOverride
            )
            let payloadHandler = SubAgentReturnPayloadHandler()
            let runSession = SubAgentRunSession(
                promptAssembler: promptAssembler,
                payloadHandler: payloadHandler,
                sessionState: sessionState,
                transcriptLogger: transcriptLogger,
                transcriptFinalizer: transcriptFinalizer,
                agentName: configuration.definition.name,
                maximumReturnPayloadAttempts: Self.maximumReturnPayloadAttempts
            )
            let payload = try await runSession.run(
                request: request,
                coordinator: coordinator
            )
            return payload
        } catch {
            await transcriptFinalizer.recordFailure(error)
            throw error
        }
    }

}
