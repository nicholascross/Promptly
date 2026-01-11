import PromptlyKit

public struct DetachedTaskRunner: Sendable {
    private let agentName: String
    private let promptAssembler: DetachedTaskPromptAssembler
    private let modelRunner: any DetachedTaskModelRunner
    private let returnPayloadResolver: any DetachedTaskReturnPayloadResolving
    private let resumeStore: (any DetachedTaskResumeStoring)?
    private let logSink: (any DetachedTaskLogSink)?
    private let maximumReturnPayloadAttempts: Int

    public init(
        agentName: String,
        promptAssembler: DetachedTaskPromptAssembler,
        modelRunner: any DetachedTaskModelRunner,
        returnPayloadResolver: any DetachedTaskReturnPayloadResolving,
        resumeStore: (any DetachedTaskResumeStoring)? = nil,
        logSink: (any DetachedTaskLogSink)? = nil,
        maximumReturnPayloadAttempts: Int = 2
    ) {
        self.agentName = agentName
        self.promptAssembler = promptAssembler
        self.modelRunner = modelRunner
        self.returnPayloadResolver = returnPayloadResolver
        self.resumeStore = resumeStore
        self.logSink = logSink
        self.maximumReturnPayloadAttempts = maximumReturnPayloadAttempts
    }

    public func run(
        request: DetachedTaskRequest
    ) async throws -> DetachedTaskRunResult {
        do {
            try request.validate()

            let systemMessage = promptAssembler.makeSystemMessage()
            let userMessage = promptAssembler.makeUserMessage(for: request)
            let reminderMessage = promptAssembler.makeReturnPayloadReminderMessage()
            let resumeIdentifier = promptAssembler.normalizeResumeIdentifier(request.resumeId)
            let resumeEntry = try await resolveResumeEntry(
                for: resumeIdentifier
            )
            let handoffPlan = try promptAssembler.makeHandoffPlan(
                for: request,
                systemMessage: systemMessage,
                userMessage: userMessage,
                resumeEntry: resumeEntry
            )

            let resumePrefixMessages: [PromptMessage]
            if resumeEntry != nil,
               promptAssembler.api == .chatCompletions {
                resumePrefixMessages = try handoffPlan.resumePrefixProvider(
                    DetachedTaskResumePrefixContext(
                        request: request,
                        resumeEntry: resumeEntry
                    )
                )
            } else {
                resumePrefixMessages = []
            }

            let context = try promptAssembler.initialContext(
                handoffMessages: handoffPlan.handoffMessages,
                resumePrefixMessages: resumePrefixMessages,
                userMessage: userMessage,
                resumeEntry: resumeEntry
            )

            let logSink = logSink
            var currentContext = context
            var attempt = 0
            var didSendReminder = false
            var combinedConversationEntries: [PromptMessage] = []
            var latestResumeToken = resumeEntry?.resumeToken
            var payloadCandidate: DetachedTaskReturnPayload?

            while payloadCandidate == nil {
                attempt += 1
                let result = try await modelRunner.run(
                    context: currentContext,
                    onEvent: { event in
                        await logSink?.handle(event: event)
                    }
                )
                if let resumeToken = result.resumeToken {
                    latestResumeToken = resumeToken
                }
                combinedConversationEntries.append(contentsOf: result.conversationEntries)

                if let returnedPayload = returnPayloadResolver.extractReturnPayload(
                    from: result.conversationEntries
                ) {
                    payloadCandidate = returnedPayload
                    break
                }

                if attempt >= maximumReturnPayloadAttempts {
                    break
                }

                didSendReminder = true
                let followUpMessages = handoffPlan.followUpMessageProvider(
                    DetachedTaskFollowUpContext(
                        request: request,
                        userMessage: userMessage,
                        handoffMessages: handoffPlan.handoffMessages,
                        resumePrefixMessages: resumePrefixMessages,
                        resumeEntry: resumeEntry,
                        conversationEntries: combinedConversationEntries
                    )
                )
                currentContext = promptAssembler.followUpContext(
                    resumeToken: latestResumeToken,
                    chatMessages: followUpMessages,
                    reminderMessage: reminderMessage
                )
            }

            let resolution = returnPayloadResolver.resolvePayload(
                candidate: payloadCandidate,
                conversationEntries: combinedConversationEntries
            )
            let processedPayload = handoffPlan.returnPayloadProcessor(
                DetachedTaskReturnProcessingContext(
                    request: request,
                    handoffMessages: handoffPlan.handoffMessages,
                    conversationEntries: combinedConversationEntries,
                    payload: resolution.payload,
                    didUseFallback: resolution.didUseFallback
                )
            )
            let needsFollowUp = returnPayloadResolver.needsFollowUp(
                in: processedPayload
            )

            var payloadWithResumeId = processedPayload
            if needsFollowUp, let resumeStore {
                let storedResumeEntry = await resumeStore.storeResumeEntry(
                    resumeId: resumeIdentifier,
                    agentName: agentName,
                    conversationEntries: combinedConversationEntries,
                    resumeToken: latestResumeToken,
                    forkedTranscript: forkedTranscriptForStorage(
                        request: request,
                        resumeEntry: resumeEntry
                    )
                )
                payloadWithResumeId = payloadWithResumeId.withResumeId(
                    storedResumeEntry.resumeId
                )
            } else {
                if let resumeIdentifier, let resumeStore {
                    await resumeStore.removeResumeEntry(for: resumeIdentifier)
                }
                payloadWithResumeId = payloadWithResumeId.withResumeId(nil)
            }

            var payloadWithLogPath = payloadWithResumeId
            if let logPath = logSink?.logPath {
                payloadWithLogPath = payloadWithLogPath.withLogPath(logPath)
            }

            await logSink?.recordCompletion(
                payload: payloadWithLogPath,
                didUseFallbackPayload: resolution.didUseFallback
            )

            return DetachedTaskRunResult(
                payload: payloadWithLogPath,
                didUseFallbackPayload: resolution.didUseFallback,
                didSendReminder: didSendReminder,
                needsFollowUp: needsFollowUp
            )
        } catch {
            await logSink?.recordFailure(error)
            throw error
        }
    }

    private func resolveResumeEntry(
        for resumeIdentifier: String?
    ) async throws -> DetachedTaskResumeEntry? {
        guard let resumeIdentifier else {
            return nil
        }
        guard let resumeStore else {
            throw DetachedTaskRunnerError.missingResumeStore(
                resumeIdentifier: resumeIdentifier
            )
        }
        guard let resumeEntry = await resumeStore.entry(
            for: resumeIdentifier
        ) else {
            throw DetachedTaskRunnerError.invalidResumeIdentifier(
                resumeIdentifier: resumeIdentifier
            )
        }
        guard resumeEntry.agentName == agentName else {
            throw DetachedTaskRunnerError.resumeAgentMismatch(
                resumeIdentifier: resumeIdentifier,
                expectedAgentName: agentName,
                actualAgentName: resumeEntry.agentName
            )
        }
        return resumeEntry
    }

    private func forkedTranscriptForStorage(
        request: DetachedTaskRequest,
        resumeEntry: DetachedTaskResumeEntry?
    ) -> [DetachedTaskForkedTranscriptEntry]? {
        switch request.handoffStrategy {
        case .contextPack:
            return nil
        case .forkedContext:
            if let entries = request.forkedTranscript,
               !entries.isEmpty {
                return entries
            }
            return resumeEntry?.forkedTranscript
        }
    }
}
