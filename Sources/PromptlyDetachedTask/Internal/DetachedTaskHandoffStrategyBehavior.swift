import PromptlyKit

protocol DetachedTaskHandoffStrategyBehavior: Sendable {
    func makeHandoffMessages(
        request: DetachedTaskRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> [PromptMessage]

    func makeFollowUpMessages(
        context: DetachedTaskFollowUpContext
    ) -> [PromptMessage]

    func resumePrefixMessages(
        context: DetachedTaskResumePrefixContext
    ) throws -> [PromptMessage]

    func returnPayloadProcessor(
        context: DetachedTaskReturnProcessingContext
    ) -> DetachedTaskReturnPayload
}

struct DetachedTaskContextPackHandoffStrategy: DetachedTaskHandoffStrategyBehavior {
    func makeHandoffMessages(
        request: DetachedTaskRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> [PromptMessage] {
        [systemMessage, userMessage]
    }

    func makeFollowUpMessages(
        context: DetachedTaskFollowUpContext
    ) -> [PromptMessage] {
        composeFollowUpMessages(context: context)
    }

    func resumePrefixMessages(
        context: DetachedTaskResumePrefixContext
    ) throws -> [PromptMessage] {
        []
    }

    func returnPayloadProcessor(
        context: DetachedTaskReturnProcessingContext
    ) -> DetachedTaskReturnPayload {
        context.payload
    }
}

struct DetachedTaskForkedContextHandoffStrategy: DetachedTaskHandoffStrategyBehavior {
    private static let boundaryText = """
Forked transcript (read only, may be incomplete) follows.
Only the tools available in this session may be used.
"""

    func makeHandoffMessages(
        request: DetachedTaskRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: DetachedTaskResumeEntry?
    ) throws -> [PromptMessage] {
        guard request.handoffStrategy == .forkedContext else {
            throw DetachedTaskValidationError.missingForkedTranscript
        }
        guard let entries = request.forkedTranscript, !entries.isEmpty else {
            guard resumeEntry != nil else {
                throw DetachedTaskValidationError.emptyForkedTranscript
            }
            return [systemMessage, userMessage]
        }
        let validatedEntries = try DetachedTaskForkedTranscriptValidator.validatedEntries(entries)
        let forkedTranscriptMessages = validatedEntries.map { entry in
            PromptMessage(
                role: entry.role,
                content: .text(entry.content)
            )
        }
        let boundaryMessage = PromptMessage(
            role: .system,
            content: .text(Self.boundaryText)
        )
        return [systemMessage, boundaryMessage] + forkedTranscriptMessages + [userMessage]
    }

    func makeFollowUpMessages(
        context: DetachedTaskFollowUpContext
    ) -> [PromptMessage] {
        composeFollowUpMessages(context: context)
    }

    func resumePrefixMessages(
        context: DetachedTaskResumePrefixContext
    ) throws -> [PromptMessage] {
        guard context.request.handoffStrategy == .forkedContext else {
            throw DetachedTaskValidationError.missingForkedTranscript
        }

        let resolvedEntries: [DetachedTaskForkedTranscriptEntry]
        if let entries = context.request.forkedTranscript, !entries.isEmpty {
            resolvedEntries = entries
        } else if let storedEntries = context.resumeEntry?.forkedTranscript,
                  !storedEntries.isEmpty {
            resolvedEntries = storedEntries
        } else {
            throw DetachedTaskValidationError.missingForkedTranscript
        }

        let validatedEntries = try DetachedTaskForkedTranscriptValidator.validatedEntries(
            resolvedEntries
        )
        let forkedTranscriptMessages = validatedEntries.map { entry in
            PromptMessage(
                role: entry.role,
                content: .text(entry.content)
            )
        }
        let boundaryMessage = PromptMessage(
            role: .system,
            content: .text(Self.boundaryText)
        )
        return [boundaryMessage] + forkedTranscriptMessages
    }

    func returnPayloadProcessor(
        context: DetachedTaskReturnProcessingContext
    ) -> DetachedTaskReturnPayload {
        context.payload
    }
}

extension DetachedTaskHandoffStrategy {
    func makeBehavior() -> any DetachedTaskHandoffStrategyBehavior {
        switch self {
        case .contextPack:
            return DetachedTaskContextPackHandoffStrategy()
        case .forkedContext:
            return DetachedTaskForkedContextHandoffStrategy()
        }
    }
}

private func composeFollowUpMessages(
    context: DetachedTaskFollowUpContext
) -> [PromptMessage] {
    var messages: [PromptMessage]
    if let resumeEntry = context.resumeEntry {
        messages = context.resumePrefixMessages + resumeEntry.conversationEntries
        messages.append(context.userMessage)
    } else {
        messages = context.handoffMessages
    }
    if !context.conversationEntries.isEmpty {
        messages.append(contentsOf: context.conversationEntries)
    }
    return messages
}
