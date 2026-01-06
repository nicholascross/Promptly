import Foundation
import PromptlyKit
import PromptlyKitUtils

struct SubAgentPromptAssembler: Sendable {
    private static let baseSystemPrompt = """
You are a Promptly sub agent running in an isolated session.
Follow the system guidance and the user request.
Use the available tools when they help you.
Do not ask for confirmation of provided details; if the request is actionable, proceed and note any assumptions.
Never ask the user questions directly. If you need more input, call \(ReturnToSupervisorTool.toolName) with needsMoreInformation set to true and include requestedInformation.
When you finish, call \(ReturnToSupervisorTool.toolName) exactly once with the required payload and stop.
You may send status updates with \(ReportProgressToSupervisorTool.toolName).
"""

    private static let returnPayloadReminderText = """
Your previous response did not call \(ReturnToSupervisorTool.toolName).
Stop and call \(ReturnToSupervisorTool.toolName) exactly once with the required payload.
If you need more input, set needsMoreInformation to true and include requestedInformation.
Do not ask the user questions directly.
"""

    private let configuration: SubAgentConfiguration
    private let sessionState: SubAgentSessionState
    private let apiOverride: Config.API?

    init(
        configuration: SubAgentConfiguration,
        sessionState: SubAgentSessionState,
        apiOverride: Config.API? = nil
    ) {
        self.configuration = configuration
        self.sessionState = sessionState
        self.apiOverride = apiOverride
    }

    func makeSystemMessage() -> PromptMessage {
        let systemPrompt = [
            Self.baseSystemPrompt,
            configuration.definition.systemPrompt
        ].joined(separator: "\n\n")

        return PromptMessage(
            role: .system,
            content: .text(systemPrompt)
        )
    }

    func makeUserMessage(for request: SubAgentToolRequest) -> PromptMessage {
        PromptMessage(
            role: .user,
            content: .text(buildUserMessageBody(for: request))
        )
    }

    func makeReturnPayloadReminderMessage() -> PromptMessage {
        PromptMessage(
            role: .user,
            content: .text(Self.returnPayloadReminderText)
        )
    }

    func normalizeResumeIdentifier(_ resumeIdentifier: String?) -> String? {
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

    func resolveResumeEntry(
        for resumeIdentifier: String?
    ) async throws -> SubAgentResumeEntry? {
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

    func initialContext(
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: SubAgentResumeEntry?
    ) throws -> (context: PromptRunContext, effectiveApi: Config.API) {
        let effectiveApi = apiOverride ?? configuration.configuration.api

        let context: PromptRunContext
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
            context = .messages([
                systemMessage,
                userMessage
            ])
        }

        return (context, effectiveApi)
    }

    func chatMessages(
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

    func followUpContext(
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
}
