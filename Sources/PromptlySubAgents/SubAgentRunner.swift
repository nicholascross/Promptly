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
Do not ask for confirmation of provided details; if the request is actionable, proceed and note any assumptions.
Never ask the user questions directly. If you need more input, call \(ReturnToSupervisorTool.toolName) with needsMoreInformation set to true and include requestedInformation.
When you finish, call \(ReturnToSupervisorTool.toolName) exactly once with the required payload and stop.
You may send status updates with \(ReportProgressToSupervisorTool.toolName).
"""
    private static let maximumReturnPayloadAttempts = 2
    private static let emptyAssistantFallbackText = "Sub agent response was empty."
    private static let missingReturnPayloadSummary = "Sub agent did not complete the task."
    private static let missingReturnDecisionReason = "Sub agent did not call ReturnToSupervisor after reminder."
    private static let returnPayloadReminderText = """
Your previous response did not call \(ReturnToSupervisorTool.toolName).
Stop and call \(ReturnToSupervisorTool.toolName) exactly once with the required payload.
If you need more input, set needsMoreInformation to true and include requestedInformation.
Do not ask the user questions directly.
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

        let systemMessage = makeSystemMessage()
        let userMessage = makeUserMessage(for: request)
        let reminderMessage = makeReturnPayloadReminderMessage()
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
            var currentContext = context
            var attempt = 0
            var combinedConversationEntries: [PromptMessage] = []
            var latestResumeToken = resumeEntry?.resumeToken
            var payload: JSONValue?
            var usedMissingReturnPayload = false

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

                if let returnedPayload = firstReturnPayload(from: result.conversationEntries) {
                    payload = returnedPayload
                    break
                }

                if attempt >= Self.maximumReturnPayloadAttempts {
                    payload = missingReturnPayload(from: combinedConversationEntries)
                    usedMissingReturnPayload = true
                    break
                }

                let followUpMessages = chatMessages(
                    systemMessage: systemMessage,
                    userMessage: userMessage,
                    resumeEntry: resumeEntry,
                    conversationEntries: combinedConversationEntries
                )
                currentContext = followUpContext(
                    effectiveApi: effectiveApi,
                    resumeToken: latestResumeToken,
                    chatMessages: followUpMessages,
                    reminderMessage: reminderMessage
                )
            }

            let resolvedPayload = payload ?? missingReturnPayload(from: combinedConversationEntries)
            let didUseMissingReturnPayload = usedMissingReturnPayload || payload == nil

            var payloadWithLogPath = attachLogPath(
                to: resolvedPayload,
                logPath: transcriptLogger?.logPath
            )
            if needsFollowUp(in: payloadWithLogPath) {
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
                payloadWithLogPath = attachResumeId(
                    storedResumeEntry.resumeId,
                    to: payloadWithLogPath
                )
            } else {
                payloadWithLogPath = removeResumeId(from: payloadWithLogPath)
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

    private func makeReturnPayloadReminderMessage() -> PromptMessage {
        PromptMessage(
            role: .user,
            content: .text(Self.returnPayloadReminderText)
        )
    }

    private func chatMessages(
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: SubAgentResumeEntry?,
        conversationEntries: [PromptMessage]
    ) -> [PromptMessage] {
        var messages: [PromptMessage]
        if let resumeEntry {
            messages = resumeEntry.conversationEntries
            messages.append(userMessage)
        } else {
            messages = [systemMessage, userMessage]
        }
        if !conversationEntries.isEmpty {
            messages.append(contentsOf: conversationEntries)
        }
        return messages
    }

    private func followUpContext(
        effectiveApi: Config.API,
        resumeToken: String?,
        chatMessages: [PromptMessage],
        reminderMessage: PromptMessage
    ) -> PromptRunContext {
        switch effectiveApi {
        case .responses:
            if let resumeToken {
                return .resume(
                    resumeToken: resumeToken,
                    requestMessages: [reminderMessage]
                )
            }
            var messages = chatMessages
            messages.append(reminderMessage)
            return .messages(messages)
        case .chatCompletions:
            var messages = chatMessages
            messages.append(reminderMessage)
            return .messages(messages)
        }
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

    private func needsFollowUp(in payload: JSONValue) -> Bool {
        guard case let .object(object) = payload else {
            return false
        }
        let needsMoreInformation: Bool
        if case let .bool(needsMore)? = object["needsMoreInformation"] {
            needsMoreInformation = needsMore
        } else {
            needsMoreInformation = false
        }

        let needsSupervisorDecision: Bool
        if case let .bool(needsDecision)? = object["needsSupervisorDecision"] {
            needsSupervisorDecision = needsDecision
        } else {
            needsSupervisorDecision = false
        }

        return needsMoreInformation || needsSupervisorDecision
    }

    private func attachResumeId(_ resumeId: String, to payload: JSONValue) -> JSONValue {
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated["resumeId"] = .string(resumeId)
        return .object(updated)
    }

    private func removeResumeId(from payload: JSONValue) -> JSONValue {
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated.removeValue(forKey: "resumeId")
        return .object(updated)
    }

    private func missingReturnPayload(
        from conversationEntries: [PromptMessage]
    ) -> JSONValue {
        let assistantText = lastAssistantResponseText(from: conversationEntries)
        let message = """
Sub agent did not complete the task.
Last assistant response:
\(assistantText)
"""
        return .object([
            "result": .string(message),
            "summary": .string(Self.missingReturnPayloadSummary),
            "needsSupervisorDecision": .bool(true),
            "decisionReason": .string(Self.missingReturnDecisionReason),
            "supervisorMessage": .object([
                "role": .string("user"),
                "content": .string(message)
            ])
        ])
    }

    private func lastAssistantResponseText(
        from conversationEntries: [PromptMessage]
    ) -> String {
        guard let content = latestAssistantContent(in: conversationEntries) else {
            return Self.emptyAssistantFallbackText
        }
        return assistantText(from: content)
    }

    private func latestAssistantContent(
        in conversationEntries: [PromptMessage]
    ) -> PromptContent? {
        for entry in conversationEntries.reversed() {
            guard entry.role == .assistant else { continue }
            return entry.content
        }
        return nil
    }

    private func assistantText(from content: PromptContent) -> String {
        switch content {
        case let .text(text):
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? Self.emptyAssistantFallbackText : text
        case let .json(value):
            return encodedJSONText(from: value) ?? value.description
        case .empty:
            return Self.emptyAssistantFallbackText
        }
    }

    private func encodedJSONText(from value: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}
