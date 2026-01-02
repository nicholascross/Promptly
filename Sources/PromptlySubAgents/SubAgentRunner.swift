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
    private static let baseSystemPrompt = """
You are a Promptly sub agent running in an isolated session.
Follow the system guidance and the user request.
Use the available tools when they help you.
When you finish, call \(ReturnToSupervisorTool.toolName) exactly once with the required payload and stop.
You may send status updates with \(ReportProgressToSupervisorTool.toolName).
"""

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

        let userMessage = makeUserMessage(for: request)
        let resumeIdentifier = normalizeResumeIdentifier(request.resumeId)
        let resumeEntry = try await resolveResumeEntry(for: resumeIdentifier)
        let context: PromptRunContext

        let effectiveApi = apiOverride ?? configuration.configuration.api
        if let resumeEntry {
            switch effectiveApi {
            case .responses:
                guard let storedResumeToken = resumeEntry.resumeToken else {
                    throw SubAgentToolError.missingResponsesResumeToken(
                        agentName: configuration.definition.name,
                        resumeId: resumeEntry.resumeId
                    )
                }
                context = .resume(
                    resumeToken: storedResumeToken,
                    requestMessages: [userMessage]
                )
            case .chatCompletions:
                context = .messages(
                    resumeEntry.conversationEntries + [userMessage]
                )
            }
        } else {
            let systemMessage = makeSystemMessage()
            context = .messages([
                systemMessage,
                userMessage
            ])
        }
        let tools = try makeTools(transcriptLogger: transcriptLogger)
        let coordinator = try coordinatorFactory(tools)

        do {
            let result = try await coordinator.prompt(
                context: context,
                onEvent: { event in
                    await transcriptLogger?.handle(event: event)
                }
            )

            guard let payload = firstReturnPayload(from: result.conversationEntries) else {
                await transcriptLogger?.finish(status: "missing_return_payload", error: nil)
                didFinishLogging = true
                throw SubAgentToolError.missingReturnPayload(agentName: configuration.definition.name)
            }

            var payloadWithLogPath = attachLogPath(
                to: payload,
                logPath: transcriptLogger?.logPath
            )
            payloadWithLogPath = removeResumeIdIfNotNeeded(from: payloadWithLogPath)
            if needsMoreInformation(in: payloadWithLogPath) {
                let mergedConversationEntries: [PromptMessage]
                if let resumeEntry, effectiveApi == .responses {
                    mergedConversationEntries = resumeEntry.conversationEntries + result.conversationEntries
                } else {
                    mergedConversationEntries = result.conversationEntries
                }
                let storedResumeEntry = await sessionState.storeResumeEntry(
                    resumeId: resumeIdentifier,
                    agentName: configuration.definition.name,
                    conversationEntries: mergedConversationEntries,
                    resumeToken: result.resumeToken
                )
                payloadWithLogPath = attachResumeId(
                    storedResumeEntry.resumeId,
                    to: payloadWithLogPath
                )
            }
            await transcriptLogger?.recordReturnPayload(payloadWithLogPath)
            await transcriptLogger?.finish(status: "completed", error: nil)
            didFinishLogging = true

            return payloadWithLogPath
        } catch {
            if !didFinishLogging {
                await transcriptLogger?.finish(status: "failed", error: error)
            }
            throw error
        }
    }

    private func makeSystemMessage() -> PromptMessage {
        let systemPrompt = [
            Self.baseSystemPrompt,
            configuration.definition.systemPrompt
        ].joined(separator: "\n\n")

        return PromptMessage(
            role: .system,
            content: .text(systemPrompt)
        )
    }

    private func makeUserMessage(for request: SubAgentToolRequest) -> PromptMessage {
        PromptMessage(
            role: .user,
            content: .text(buildUserMessageBody(for: request))
        )
    }

    private func buildUserMessageBody(for request: SubAgentToolRequest) -> String {
        var sections: [String] = []
        sections.append("Task:\n\(request.task)")

        if let goals = request.goals, !goals.isEmpty {
            sections.append("Goals:\n\(formatList(goals))")
        }

        if let constraints = request.constraints, !constraints.isEmpty {
            sections.append("Constraints:\n\(formatList(constraints))")
        }

        if let contextPack = request.contextPack {
            sections.append("Context Pack:\n\(formatContextPack(contextPack))")
        }

        return sections.joined(separator: "\n\n")
    }

    private func formatList(_ items: [String]) -> String {
        items.map { "- \($0)" }.joined(separator: "\n")
    }

    private func formatContextPack(_ contextPack: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(contextPack),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return contextPack.description
    }

    private func resolveResumeEntry(for resumeIdentifier: String?) async throws -> SubAgentResumeEntry? {
        guard let resumeIdentifier else {
            return nil
        }
        guard let resumeEntry = await sessionState.entry(for: resumeIdentifier) else {
            throw SubAgentToolError.invalidResumeId(resumeId: resumeIdentifier)
        }
        guard resumeEntry.agentName == configuration.definition.name else {
            throw SubAgentToolError.resumeAgentMismatch(
                resumeId: resumeIdentifier,
                expectedAgentName: configuration.definition.name,
                actualAgentName: resumeEntry.agentName
            )
        }
        return resumeEntry
    }

    private func normalizeResumeIdentifier(_ resumeIdentifier: String?) -> String? {
        guard let resumeIdentifier else {
            return nil
        }
        let trimmedIdentifier = resumeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            return nil
        }
        guard let parsedIdentifier = UUID(uuidString: trimmedIdentifier) else {
            return nil
        }
        return parsedIdentifier.uuidString.lowercased()
    }

    func makeTools(
        transcriptLogger: SubAgentTranscriptLogger?
    ) throws -> [any ExecutableTool] {
        let toolFactory = ToolFactory(
            fileManager: fileManager,
            toolsFileName: toolSettings.toolsFileName
        )
        let baseTools = try toolFactory.makeTools(
            config: configuration.configuration,
            includeTools: toolSettings.includeTools,
            excludeTools: toolSettings.excludeTools,
            toolOutput: toolOutput
        )

        let filteredTools = baseTools.filter { tool in
            !isDisallowedToolName(tool.name)
        }

        var tools = filteredTools
        tools.append(
            ReturnToSupervisorTool()
        )
        tools.append(
            ReportProgressToSupervisorTool(
                agentName: configuration.definition.name,
                toolOutput: toolOutput,
                transcriptLogger: transcriptLogger
            )
        )

        return tools
    }

    private func isDisallowedToolName(_ name: String) -> Bool {
        if name.hasPrefix("SubAgent-") {
            return true
        }
        let reservedNames = [
            ReturnToSupervisorTool.toolName,
            ReportProgressToSupervisorTool.toolName
        ]
        return reservedNames.contains(name)
    }

    private func firstReturnPayload(from conversationEntries: [PromptMessage]) -> JSONValue? {
        for entry in conversationEntries {
            guard entry.role == .assistant else { continue }
            guard let toolCalls = entry.toolCalls else { continue }
            for toolCall in toolCalls where toolCall.name == ReturnToSupervisorTool.toolName {
                if let output = toolOutput(for: toolCall.id, in: conversationEntries) {
                    return output
                }
                return toolCall.arguments
            }
        }
        return nil
    }

    private func toolOutput(
        for toolCallIdentifier: String?,
        in conversationEntries: [PromptMessage]
    ) -> JSONValue? {
        guard let toolCallIdentifier else {
            return nil
        }
        for entry in conversationEntries {
            guard entry.role == .tool else { continue }
            guard entry.toolCallId == toolCallIdentifier else { continue }
            if case let .json(value) = entry.content {
                return value
            }
        }
        return nil
    }

    private func attachLogPath(to payload: JSONValue, logPath: String?) -> JSONValue {
        guard let logPath else {
            return payload
        }
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated["logPath"] = .string(logPath)
        return .object(updated)
    }

    private func needsMoreInformation(in payload: JSONValue) -> Bool {
        guard case let .object(object) = payload else {
            return false
        }
        guard case let .bool(needsMore)? = object["needsMoreInformation"] else {
            return false
        }
        return needsMore
    }

    private func attachResumeId(_ resumeId: String, to payload: JSONValue) -> JSONValue {
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated["resumeId"] = .string(resumeId)
        return .object(updated)
    }

    private func removeResumeIdIfNotNeeded(from payload: JSONValue) -> JSONValue {
        guard case let .object(object) = payload else {
            return payload
        }
        guard case let .bool(needsMoreInformation) = object["needsMoreInformation"],
              needsMoreInformation else {
            var updated = object
            updated.removeValue(forKey: "resumeId")
            return .object(updated)
        }
        return payload
    }
}
