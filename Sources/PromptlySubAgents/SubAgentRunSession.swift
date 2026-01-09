import Foundation
import PromptlyKit
import PromptlyKitUtils

struct SubAgentRunSession: Sendable {
    private let promptAssembler: SubAgentPromptAssembler
    private let payloadHandler: SubAgentReturnPayloadHandler
    private let sessionState: SubAgentSessionState
    private let transcriptLogger: SubAgentTranscriptLogger?
    private let transcriptFinalizer: SubAgentTranscriptFinalizer
    private let agentName: String
    private let maximumReturnPayloadAttempts: Int

    init(
        promptAssembler: SubAgentPromptAssembler,
        payloadHandler: SubAgentReturnPayloadHandler,
        sessionState: SubAgentSessionState,
        transcriptLogger: SubAgentTranscriptLogger?,
        transcriptFinalizer: SubAgentTranscriptFinalizer,
        agentName: String,
        maximumReturnPayloadAttempts: Int
    ) {
        self.promptAssembler = promptAssembler
        self.payloadHandler = payloadHandler
        self.sessionState = sessionState
        self.transcriptLogger = transcriptLogger
        self.transcriptFinalizer = transcriptFinalizer
        self.agentName = agentName
        self.maximumReturnPayloadAttempts = maximumReturnPayloadAttempts
    }

    func run(
        request: SubAgentToolRequest,
        coordinator: PromptEndpoint
    ) async throws -> JSONValue {
        let transcriptLogger = transcriptLogger
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

            if attempt >= maximumReturnPayloadAttempts {
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
            logPath: transcriptFinalizer.logPath
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
                agentName: agentName,
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
        await transcriptFinalizer.recordCompletion(
            payload: payloadWithLogPath,
            didUseMissingReturnPayload: didUseMissingReturnPayload
        )

        return payloadWithLogPath
    }
}
