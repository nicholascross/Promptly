import PromptlyKit
import PromptlyKitUtils

protocol SubAgentHandoffStrategyBehavior: Sendable {
    func makeHandoffMessages(
        request: SubAgentToolRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: SubAgentResumeEntry?
    ) throws -> [PromptMessage]

    func makeFollowUpMessages(
        context: SubAgentFollowUpContext
    ) -> [PromptMessage]

    func resumePrefixMessages(
        context: SubAgentResumePrefixContext
    ) throws -> [PromptMessage]

    func returnPayloadProcessor(
        context: SubAgentReturnProcessingContext
    ) -> JSONValue
}

struct SubAgentContextPackHandoffStrategy: SubAgentHandoffStrategyBehavior {
    func makeHandoffMessages(
        request: SubAgentToolRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: SubAgentResumeEntry?
    ) throws -> [PromptMessage] {
        [systemMessage, userMessage]
    }

    func makeFollowUpMessages(
        context: SubAgentFollowUpContext
    ) -> [PromptMessage] {
        composeFollowUpMessages(context: context)
    }

    func resumePrefixMessages(
        context: SubAgentResumePrefixContext
    ) throws -> [PromptMessage] {
        []
    }

    func returnPayloadProcessor(
        context: SubAgentReturnProcessingContext
    ) -> JSONValue {
        context.payload
    }
}

struct SubAgentForkedContextHandoffStrategy: SubAgentHandoffStrategyBehavior {
    private static let boundaryText = """
Forked transcript (read only, may be incomplete) follows.
Only the tools available in this session may be used.
"""

    private static let maximumMessageCount = 40
    private static let maximumCharacterCount = 20000

    func makeHandoffMessages(
        request: SubAgentToolRequest,
        systemMessage: PromptMessage,
        userMessage: PromptMessage,
        resumeEntry: SubAgentResumeEntry?
    ) throws -> [PromptMessage] {
        guard case let .forkedContext(entries) = request.handoff else {
            throw SubAgentToolError.missingForkedTranscript
        }
        if entries.isEmpty {
            guard resumeEntry != nil else {
                throw SubAgentToolError.emptyForkedTranscript
            }
            return [systemMessage, userMessage]
        }
        let forkedTranscriptMessages = try validatedForkedTranscriptMessages(
            entries: entries
        )
        let boundaryMessage = PromptMessage(
            role: .system,
            content: .text(Self.boundaryText)
        )
        return [systemMessage, boundaryMessage] + forkedTranscriptMessages + [userMessage]
    }

    func makeFollowUpMessages(
        context: SubAgentFollowUpContext
    ) -> [PromptMessage] {
        composeFollowUpMessages(context: context)
    }

    func resumePrefixMessages(
        context: SubAgentResumePrefixContext
    ) throws -> [PromptMessage] {
        guard case let .forkedContext(entries) = context.request.handoff else {
            throw SubAgentToolError.missingForkedTranscript
        }

        let resolvedEntries: [SubAgentForkedTranscriptEntry]
        if !entries.isEmpty {
            resolvedEntries = entries
        } else if let storedEntries = context.resumeEntry?.forkedTranscript, !storedEntries.isEmpty {
            resolvedEntries = storedEntries
        } else {
            throw SubAgentToolError.missingForkedTranscript
        }

        let forkedTranscriptMessages = try validatedForkedTranscriptMessages(
            entries: resolvedEntries
        )
        let boundaryMessage = PromptMessage(
            role: .system,
            content: .text(Self.boundaryText)
        )
        return [boundaryMessage] + forkedTranscriptMessages
    }

    func returnPayloadProcessor(
        context: SubAgentReturnProcessingContext
    ) -> JSONValue {
        context.payload
    }

    private func validatedForkedTranscriptMessages(
        entries: [SubAgentForkedTranscriptEntry]
    ) throws -> [PromptMessage] {
        guard !entries.isEmpty else {
            throw SubAgentToolError.emptyForkedTranscript
        }

        var totalCharacters = 0
        var messages: [PromptMessage] = []
        messages.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            let roleText = entry.role.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !roleText.isEmpty else {
                throw SubAgentToolError.emptyForkedTranscriptRole(index: index)
            }
            let normalizedRole = roleText.lowercased()
            let role: PromptRole
            switch normalizedRole {
            case "user":
                role = .user
            case "assistant":
                role = .assistant
            default:
                throw SubAgentToolError.invalidForkedTranscriptRole(index: index, role: entry.role)
            }

            let trimmedContent = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else {
                throw SubAgentToolError.emptyForkedTranscriptContent(index: index)
            }

            totalCharacters += entry.content.count
            if messages.count + 1 > Self.maximumMessageCount
                || totalCharacters > Self.maximumCharacterCount {
                throw SubAgentToolError.forkedTranscriptTooLarge(
                    maximumMessageCount: Self.maximumMessageCount,
                    maximumCharacterCount: Self.maximumCharacterCount
                )
            }

            messages.append(
                PromptMessage(
                    role: role,
                    content: .text(entry.content)
                )
            )
        }

        return messages
    }
}

extension SubAgentHandoff {
    func makeBehavior() -> any SubAgentHandoffStrategyBehavior {
        switch self {
        case .contextPack:
            return SubAgentContextPackHandoffStrategy()
        case .forkedContext:
            return SubAgentForkedContextHandoffStrategy()
        }
    }
}

private func composeFollowUpMessages(
    context: SubAgentFollowUpContext
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
