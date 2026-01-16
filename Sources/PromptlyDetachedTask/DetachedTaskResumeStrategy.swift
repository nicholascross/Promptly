import PromptlyKit

public protocol DetachedTaskResumeStrategy: Sendable {
    func resumePrefixMessages(
        request: DetachedTaskRequest,
        resumeEntry: DetachedTaskResumeEntry?,
        resumePrefixProvider: @Sendable (DetachedTaskResumePrefixContext) throws -> [PromptMessage]
    ) throws -> [PromptMessage]

    func initialContext(
        handoffMessages: [PromptMessage],
        resumePrefixMessages: [PromptMessage],
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> PromptRunContext

    func followUpContext(
        resumeToken: String?,
        chatMessages: [PromptMessage],
        reminderMessage: PromptMessage
    ) -> PromptRunContext
}

public struct ChatCompletionsDetachedTaskResumeStrategy: DetachedTaskResumeStrategy {
    public init() {}

    public func resumePrefixMessages(
        request: DetachedTaskRequest,
        resumeEntry: DetachedTaskResumeEntry?,
        resumePrefixProvider: @Sendable (DetachedTaskResumePrefixContext) throws -> [PromptMessage]
    ) throws -> [PromptMessage] {
        guard resumeEntry != nil else {
            return []
        }
        return try resumePrefixProvider(
            DetachedTaskResumePrefixContext(
                request: request,
                resumeEntry: resumeEntry
            )
        )
    }

    public func initialContext(
        handoffMessages: [PromptMessage],
        resumePrefixMessages: [PromptMessage],
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> PromptRunContext {
        if let resumeEntry {
            var messages = resumePrefixMessages
            messages.append(contentsOf: resumeEntry.conversationEntries)
            messages.append(userMessage)
            return .messages(messages)
        }

        return .messages(handoffMessages)
    }

    public func followUpContext(
        resumeToken: String?,
        chatMessages: [PromptMessage],
        reminderMessage: PromptMessage
    ) -> PromptRunContext {
        var messages = chatMessages
        messages.append(reminderMessage)
        return .messages(messages)
    }
}

public struct ResponsesDetachedTaskResumeStrategy: DetachedTaskResumeStrategy {
    public init() {}

    public func resumePrefixMessages(
        request _: DetachedTaskRequest,
        resumeEntry _: DetachedTaskResumeEntry?,
        resumePrefixProvider _: @Sendable (DetachedTaskResumePrefixContext) throws -> [PromptMessage]
    ) throws -> [PromptMessage] {
        []
    }

    public func initialContext(
        handoffMessages: [PromptMessage],
        resumePrefixMessages: [PromptMessage],
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> PromptRunContext {
        if let resumeEntry {
            guard let storedResumeToken = resumeEntry.resumeToken else {
                throw DetachedTaskRunnerError.missingResponsesResumeToken(
                    agentName: resumeEntry.agentName,
                    resumeIdentifier: resumeEntry.resumeId
                )
            }
            return .resume(
                resumeToken: storedResumeToken,
                requestMessages: [userMessage]
            )
        }

        return .messages(handoffMessages)
    }

    public func followUpContext(
        resumeToken: String?,
        chatMessages: [PromptMessage],
        reminderMessage: PromptMessage
    ) -> PromptRunContext {
        if let resumeToken {
            return .resume(
                resumeToken: resumeToken,
                requestMessages: [reminderMessage]
            )
        }
        var messages = chatMessages
        messages.append(reminderMessage)
        return .messages(messages)
    }
}

public enum DetachedTaskResumeStrategyFactory {
    public static func make(for api: Config.API) -> any DetachedTaskResumeStrategy {
        switch api {
        case .responses:
            return ResponsesDetachedTaskResumeStrategy()
        case .chatCompletions:
            return ChatCompletionsDetachedTaskResumeStrategy()
        }
    }
}
