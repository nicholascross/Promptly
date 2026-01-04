import ArgumentParser
import Foundation
import PromptlyAssets
import PromptlyKit
import PromptlyKitUtils
import PromptlySubAgents

/// `promptly agent run <name>` - run a sub agent through a lightweight supervisor flow.
struct AgentRun: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "run",
        abstract: "Run a sub agent directly"
    )

    @Argument(help: "Name of the agent configuration to run.")
    var name: String

    @Argument(help: "Supervisor prompt to start the run.")
    var supervisorPrompt: String?

    @OptionGroup
    var configurationOptions: AgentConfigOptions

    @Option(
        name: .customLong("tools"),
        help: "Override the default shell command tools config basename (without .json)."
    )
    var toolsFileName: String = "tools"

    @Option(
        name: .customLong("include-tools"),
        help: "Include shell-command tools by name. Provide one or more substrings; only matching tools will be loaded."
    )
    var includeTools: [String] = []

    @Option(
        name: .customLong("exclude-tools"),
        help: "Exclude shell-command tools by name. Provide one or more substrings; any matching tools will be omitted."
    )
    var excludeTools: [String] = []

    @Option(
        name: .customLong("model"),
        help:
        """
        The model to use for the supervisor and sub agent sessions.
        May be an alias defined in configuration; if not specified, defaults to configuration
        """
    )
    var modelOverride: String?

    @Option(
        name: .customLong("api"),
        help: "Select backend API (responses or chat). Overrides configuration."
    )
    var apiSelection: APISelection?

    @Flag(
        name: .customLong("interactive"),
        help: "Enable interactive supervisor mode; stay open for further user input"
    )
    var interactive: Bool = false

    mutating func run() async throws {
        let fileManager = FileManager.default
        let configurationFileURL = configurationOptions.configurationFileURL()
        let agentConfigurationURL = configurationOptions.agentConfigurationURL(agentName: name)

        let bundledAgents = BundledAgentDefaults()
        let bundledAgentIdentifier = configurationOptions.agentIdentifier(agentName: name).lowercased()
        let bundledAgentData = bundledAgents.agentData(name: bundledAgentIdentifier)
        let bundledAgentURL = bundledAgents.agentURL(name: bundledAgentIdentifier)

        let config = try Config.loadConfig(
            url: configurationFileURL,
            fileManager: fileManager,
            credentialSource: SystemCredentialSource()
        )

        let subAgentSessionState = SubAgentSessionState()
        let subAgentToolFactory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: SystemCredentialSource()
        )
        let toolOutput: @Sendable (String) -> Void = { stream in
            fputs(stream, stdout)
            fflush(stdout)
        }
        let agentTool: any ExecutableTool
        if fileManager.fileExists(atPath: agentConfigurationURL.path) {
            agentTool = try subAgentToolFactory.makeTool(
                configurationFileURL: configurationFileURL,
                agentConfigurationURL: agentConfigurationURL,
                toolsFileName: toolsFileName,
                sessionState: subAgentSessionState,
                modelOverride: modelOverride,
                apiOverride: apiSelection?.configValue,
                includeTools: includeTools,
                excludeTools: excludeTools,
                toolOutput: toolOutput
            )
        } else if let bundledAgentData, let bundledAgentURL {
            agentTool = try subAgentToolFactory.makeTool(
                configurationFileURL: configurationFileURL,
                agentConfigurationData: bundledAgentData,
                agentSourceURL: bundledAgentURL,
                toolsFileName: toolsFileName,
                sessionState: subAgentSessionState,
                modelOverride: modelOverride,
                apiOverride: apiSelection?.configValue,
                includeTools: includeTools,
                excludeTools: excludeTools,
                toolOutput: toolOutput
            )
        } else {
            throw AgentRunError.agentConfigurationNotFound(agentConfigurationURL.path)
        }

        let coordinator = try PromptRunCoordinator(
            config: config,
            modelOverride: modelOverride,
            apiOverride: apiSelection?.configValue,
            tools: [agentTool]
        )

        let standardInputHandler = StandardInputHandler()
        let pipedPrompt = standardInputHandler.readPipedInput()
        let combinedPrompt = combinedSupervisorPrompt(
            argumentPrompt: supervisorPrompt,
            pipedPrompt: pipedPrompt
        )

        var conversation: [PromptMessage] = [
            PromptMessage(role: .system, content: .text(supervisorSystemPrompt(toolName: agentTool.name)))
        ]

        if let combinedPrompt {
            conversation.append(PromptMessage(role: .user, content: .text(combinedPrompt)))
            let result = try await runSupervisorOnce(
                coordinator: coordinator,
                conversation: conversation,
                toolName: agentTool.name
            )
            conversation = result.conversation
            if let payload = result.toolPayload {
                try printReturnPayload(payload)
                return
            }
        } else if !interactive {
            throw AgentRunError.missingSupervisorPrompt
        }

        if interactive {
            standardInputHandler.reopenIfNeeded()
            while true {
                print("\n> ", terminator: "")
                fflush(stdout)
                guard let line = readLine() else { break }
                conversation.append(PromptMessage(role: .user, content: .text(line)))

                let result = try await runSupervisorOnce(
                    coordinator: coordinator,
                    conversation: conversation,
                    toolName: agentTool.name
                )
                conversation = result.conversation
                if let payload = result.toolPayload {
                    try printReturnPayload(payload)
                    return
                }
            }
        }

        throw AgentRunError.missingToolInvocation(agentTool.name)
    }
}

private struct SupervisorRunResult {
    let conversation: [PromptMessage]
    let toolPayload: JSONValue?
}

private extension AgentRun {
    func supervisorSystemPrompt(toolName: String) -> String {
        """
        You are running a lightweight supervisor session for a sub agent.
        Use tool calling to assemble the request for the tool named \(toolName).
        If the required task is missing, ask the user for it instead of guessing.
        Do not fabricate goals, constraints, context pack content, or resume identifiers.
        If the user provides goals, constraints, a context pack, or a resume identifier, include them.
        When the tool returns needsMoreInformation or needsSupervisorDecision, gather the requested input or decision and call the tool again with the resumeId.
        When you have enough information, call the tool exactly once.
        After the tool completes, respond briefly based on the user prompt and the tool result.
        """
    }

    func combinedSupervisorPrompt(argumentPrompt: String?, pipedPrompt: String?) -> String? {
        let trimmedArgument = argumentPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPiped = pipedPrompt?.trimmingCharacters(in: .whitespacesAndNewlines)
        let prompts = [trimmedArgument, trimmedPiped].compactMap { $0 }.filter { !$0.isEmpty }
        guard !prompts.isEmpty else {
            return nil
        }
        return prompts.joined(separator: "\n\n")
    }

    func runSupervisorOnce(
        coordinator: PromptRunCoordinator,
        conversation: [PromptMessage],
        toolName: String
    ) async throws -> SupervisorRunResult {
        let writeToStandardOutput: @Sendable (String) async -> Void = { text in
            fputs(text, stdout)
            fflush(stdout)
        }
        let outputHandler = PromptStreamOutputHandler(
            output: .init(
                onAssistantText: writeToStandardOutput,
                onToolCallRequested: writeToStandardOutput,
                onToolCallCompleted: { _ in }
            )
        )
        let result = try await coordinator.prompt(
            context: .messages(conversation),
            onEvent: { event in
                await outputHandler.handle(event)
            }
        )

        var updatedConversation = conversation
        updatedConversation.append(contentsOf: result.conversationEntries)

        let hasAssistantText = result.conversationEntries.contains { entry in
            guard entry.role == .assistant else { return false }
            guard case let .text(message) = entry.content else { return false }
            return !message.isEmpty
        }
        if hasAssistantText {
            fputs("\n", stdout)
            fflush(stdout)
        }

        let toolPayload = try firstToolOutput(
            toolName: toolName,
            conversationEntries: result.conversationEntries
        )
        return SupervisorRunResult(conversation: updatedConversation, toolPayload: toolPayload)
    }

    func firstToolOutput(
        toolName: String,
        conversationEntries: [PromptMessage]
    ) throws -> JSONValue? {
        var toolCallIdentifier: String?
        for entry in conversationEntries {
            guard entry.role == .assistant else { continue }
            guard let toolCalls = entry.toolCalls else { continue }
            for toolCall in toolCalls where toolCall.name == toolName {
                if toolCallIdentifier != nil {
                    throw AgentRunError.multipleToolInvocations(toolName)
                }
                toolCallIdentifier = toolCall.id
            }
        }

        guard let toolCallIdentifier else {
            let toolOutputs = conversationEntries.compactMap { entry -> JSONValue? in
                guard entry.role == .tool else { return nil }
                if case let .json(output) = entry.content {
                    return output
                }
                return nil
            }
            if toolOutputs.count == 1 {
                return toolOutputs[0]
            }
            if toolOutputs.count > 1 {
                throw AgentRunError.multipleToolInvocations(toolName)
            }
            return nil
        }

        for entry in conversationEntries {
            guard entry.role == .tool else { continue }
            guard entry.toolCallId == toolCallIdentifier else { continue }
            if case let .json(output) = entry.content {
                return output
            }
        }

        throw AgentRunError.missingToolOutput(toolName)
    }

    func printReturnPayload(_ payload: JSONValue) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(payload)
        guard let text = String(data: data, encoding: .utf8) else {
            throw AgentRunError.couldNotFormatReturnPayload
        }
        print(text)
        fflush(stdout)
    }
}

private enum AgentRunError: Error, LocalizedError {
    case agentConfigurationNotFound(String)
    case missingSupervisorPrompt
    case missingToolInvocation(String)
    case multipleToolInvocations(String)
    case missingToolOutput(String)
    case couldNotFormatReturnPayload

    var errorDescription: String? {
        switch self {
        case let .agentConfigurationNotFound(path):
            return "Agent configuration not found at \(path)."
        case .missingSupervisorPrompt:
            return "No supervisor prompt provided. Provide a prompt or enable interactive mode."
        case let .missingToolInvocation(toolName):
            return "Supervisor did not call the \(toolName) tool."
        case let .multipleToolInvocations(toolName):
            return "Supervisor called the \(toolName) tool more than once."
        case let .missingToolOutput(toolName):
            return "Supervisor called the \(toolName) tool, but no output was recorded."
        case .couldNotFormatReturnPayload:
            return "Could not format the return payload as JSON."
        }
    }
}
