import Foundation
import PromptlyKit

public struct DetachedTaskPromptAssembler: Sendable {
    private let agentSystemPrompt: String
    private let returnToolName: String
    private let progressToolName: String?
    private let resumeStrategy: any DetachedTaskResumeStrategy

    public init(
        agentSystemPrompt: String,
        returnToolName: String,
        progressToolName: String?,
        api: Config.API
    ) {
        self.init(
            agentSystemPrompt: agentSystemPrompt,
            returnToolName: returnToolName,
            progressToolName: progressToolName,
            resumeStrategy: DetachedTaskResumeStrategyFactory.make(for: api)
        )
    }

    public init(
        agentSystemPrompt: String,
        returnToolName: String,
        progressToolName: String?,
        resumeStrategy: any DetachedTaskResumeStrategy
    ) {
        self.agentSystemPrompt = agentSystemPrompt
        self.returnToolName = returnToolName
        let trimmedProgressToolName = progressToolName?.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if let trimmedProgressToolName,
           !trimmedProgressToolName.isEmpty {
            self.progressToolName = trimmedProgressToolName
        } else {
            self.progressToolName = nil
        }
        self.resumeStrategy = resumeStrategy
    }

    public func makeSystemMessage() -> PromptMessage {
        let basePrompt = baseSystemPrompt()
        let trimmedAgentPrompt = agentSystemPrompt.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        let systemPrompt: String
        if trimmedAgentPrompt.isEmpty {
            systemPrompt = basePrompt
        } else {
            systemPrompt = [basePrompt, trimmedAgentPrompt].joined(separator: "\n\n")
        }

        return PromptMessage(
            role: .system,
            content: .text(systemPrompt)
        )
    }

    public func makeUserMessage(for request: DetachedTaskRequest) -> PromptMessage {
        PromptMessage(
            role: .user,
            content: .text(buildUserMessageBody(for: request))
        )
    }

    func makeHandoffPlan(
        for request: DetachedTaskRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> DetachedTaskHandoffPlan {
        let behavior = request.handoffStrategy.makeBehavior()
        let handoffMessages = try behavior.makeHandoffMessages(
            request: request,
            systemMessage: systemMessage,
            userMessage: userMessage,
            resumeEntry: resumeEntry
        )
        return DetachedTaskHandoffPlan(
            handoffMessages: handoffMessages,
            resumePrefixProvider: { context in
                try behavior.resumePrefixMessages(context: context)
            },
            followUpMessageProvider: { context in
                behavior.makeFollowUpMessages(context: context)
            },
            returnPayloadProcessor: { context in
                behavior.returnPayloadProcessor(context: context)
            }
        )
    }

    public func makeReturnPayloadReminderMessage() -> PromptMessage {
        let reminderText = """
Your previous response did not call \(returnToolName).
Stop and call \(returnToolName) exactly once with the required payload.
If you need more input, set needsMoreInformation to true and include requestedInformation.
Do not ask the user questions directly.
"""
        return PromptMessage(
            role: .user,
            content: .text(reminderText)
        )
    }

    public func normalizeResumeIdentifier(
        _ resumeIdentifier: String?
    ) -> String? {
        guard let resumeIdentifier else {
            return nil
        }
        let trimmedIdentifier = resumeIdentifier.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedIdentifier.isEmpty else {
            return nil
        }
        guard let parsedIdentifier = UUID(uuidString: trimmedIdentifier) else {
            return nil
        }
        return parsedIdentifier.uuidString.lowercased()
    }

    func resumePrefixMessages(
        request: DetachedTaskRequest,
        resumeEntry: DetachedTaskResumeEntry?,
        resumePrefixProvider: @Sendable (DetachedTaskResumePrefixContext) throws -> [PromptMessage]
    ) throws -> [PromptMessage] {
        try resumeStrategy.resumePrefixMessages(
            request: request,
            resumeEntry: resumeEntry,
            resumePrefixProvider: resumePrefixProvider
        )
    }

    public func initialContext(
        handoffMessages: [PromptMessage],
        resumePrefixMessages: [PromptMessage],
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> PromptRunContext {
        try resumeStrategy.initialContext(
            handoffMessages: handoffMessages,
            resumePrefixMessages: resumePrefixMessages,
            userMessage: userMessage,
            resumeEntry: resumeEntry
        )
    }

    public func followUpContext(
        resumeToken: String?,
        chatMessages: [PromptMessage],
        reminderMessage: PromptMessage
    ) -> PromptRunContext {
        resumeStrategy.followUpContext(
            resumeToken: resumeToken,
            chatMessages: chatMessages,
            reminderMessage: reminderMessage
        )
    }

    private func baseSystemPrompt() -> String {
        var lines = [
            "You are running a Promptly detached task session.",
            "Follow the system guidance and the user request.",
            "Use the available tools when they help you.",
            "Do not ask for confirmation of provided details; if the request is actionable, proceed and note any assumptions.",
            "Never ask the user questions directly. If you need more input, call \(returnToolName) with needsMoreInformation set to true and include requestedInformation.",
            "When you finish, call \(returnToolName) exactly once with the required payload and stop."
        ]
        if let progressToolName {
            lines.append("You may send status updates with \(progressToolName).")
        }
        return lines.joined(separator: "\n")
    }

    private func buildUserMessageBody(
        for request: DetachedTaskRequest
    ) -> String {
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

    private func formatContextPack(_ contextPack: DetachedTaskContextPack) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(contextPack),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return String(describing: contextPack)
    }
}
