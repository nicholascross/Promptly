import Darwin
import PromptlyKitUtils

public struct PromptCommandLineRunner {
    public let config: Config
    public let toolProvider: () throws -> [any ExecutableTool]
    public let modelOverride: String?
    public let apiOverride: Config.API?
    public let interactive: Bool
    public let standardInputHandler: StandardInputHandler

    public init(
        config: Config,
        toolProvider: @escaping () throws -> [any ExecutableTool],
        modelOverride: String?,
        apiOverride: Config.API?,
        interactive: Bool,
        standardInputHandler: StandardInputHandler
    ) {
        self.config = config
        self.toolProvider = toolProvider
        self.modelOverride = modelOverride
        self.apiOverride = apiOverride
        self.interactive = interactive
        self.standardInputHandler = standardInputHandler
    }

    public func run(initialMessages: [ChatMessage]) async throws {
        let availableTools = try toolProvider()
        let coordinator = try PrompterCoordinator(
            config: config,
            modelOverride: modelOverride,
            apiOverride: apiOverride,
            tools: availableTools
        )

        if initialMessages.isEmpty && !interactive {
            throw PromptSessionError.missingInput
        }

        var conversation = initialMessages
        if !conversation.isEmpty {
            let (updatedConversation, _) = try await runOnce(
                coordinator: coordinator,
                conversation: conversation
            )
            conversation = updatedConversation
        }

        try await continueInteractivelyIfNeeded(
            coordinator: coordinator,
            initialMessages: conversation
        )
    }

    private func continueInteractivelyIfNeeded(
        coordinator: PrompterCoordinator,
        initialMessages: [ChatMessage]
    ) async throws {
        guard interactive else { return }
        standardInputHandler.reopenIfNeeded()
        var conversation = initialMessages
        while true {
            print("\n> ", terminator: "")
            fflush(stdout)
            guard let line = readLine() else { break }
            conversation.append(ChatMessage(role: .user, content: .text(line)))

            let (updatedConversation, _) = try await runOnce(
                coordinator: coordinator,
                conversation: conversation
            )
            conversation = updatedConversation
        }
    }

    private func runOnce(
        coordinator: PrompterCoordinator,
        conversation: [ChatMessage]
    ) async throws -> (conversation: [ChatMessage], transcript: PromptTranscript) {
        let outputSink = StreamingOutputSink()
        let transcriptRecorder = TranscriptRecorder()

        let result = try await coordinator.run(
            messages: conversation,
            onEvent: { event in
                transcriptRecorder.handle(event)
                outputSink.handle(event)
            }
        )

        let transcript = transcriptRecorder.finishTranscript(finalAssistantText: result.finalAssistantText)

        var updatedConversation = conversation
        if let assistantText = result.finalAssistantText, !assistantText.isEmpty {
            updatedConversation.append(ChatMessage(role: .assistant, content: .text(assistantText)))
        }

        if let assistantText = result.finalAssistantText, !assistantText.isEmpty, !outputSink.didStreamAssistantText {
            fputs(assistantText, stdout)
            fputs("\n", stdout)
            fflush(stdout)
        } else if outputSink.didStreamAssistantText {
            fputs("\n", stdout)
            fflush(stdout)
        }

        return (updatedConversation, transcript)
    }
}
