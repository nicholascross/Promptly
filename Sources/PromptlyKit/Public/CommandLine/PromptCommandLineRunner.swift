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

    public func run(initialMessages: [PromptMessage]) async throws {
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
            let updatedConversation = try await runOnce(
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
        initialMessages: [PromptMessage]
    ) async throws {
        guard interactive else { return }
        standardInputHandler.reopenIfNeeded()
        var conversation = initialMessages
        while true {
            print("\n> ", terminator: "")
            fflush(stdout)
            guard let line = readLine() else { break }
            conversation.append(PromptMessage(role: .user, content: .text(line)))

            let updatedConversation = try await runOnce(
                coordinator: coordinator,
                conversation: conversation
            )
            conversation = updatedConversation
        }
    }

    private func runOnce(
        coordinator: PrompterCoordinator,
        conversation: [PromptMessage]
    ) async throws -> [PromptMessage] {
        let writeToStandardOutput: @Sendable (String) async -> Void = { text in
            fputs(text, stdout)
            fflush(stdout)
        }
        let outputHandler = PromptStreamOutputHandler(
            output: .init(
                onAssistantText: writeToStandardOutput,
                onToolCallRequested: writeToStandardOutput,
                onToolCallCompleted: writeToStandardOutput
            )
        )
        let result = try await coordinator.run(
            messages: conversation,
            onEvent: { event in
                await outputHandler.handle(event)
            }
        )

        var updatedConversation = conversation
        let assistantMessages = result.promptTranscript.compactMap { entry -> String? in
            guard case let .assistant(message) = entry else { return nil }
            return message
        }
        if !assistantMessages.isEmpty {
            for message in assistantMessages {
                updatedConversation.append(PromptMessage(role: .assistant, content: .text(message)))
            }
            fputs("\n", stdout)
            fflush(stdout)
        }

        return updatedConversation
    }
}
