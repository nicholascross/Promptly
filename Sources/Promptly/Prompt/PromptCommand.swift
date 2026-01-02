import ArgumentParser
import Foundation
import PromptlyConsole
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import PromptlySubAgents

struct PromptCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "prompt",
        abstract: "Send a prompt to the AI chat interface"
    )

    @OptionGroup
    var promptOptions: PromptOptions

    @Flag(name: .customLong("interactive"), help: "Enable interactive prompt mode; stay open for further user input")
    private var interactive: Bool = false

    mutating func run() async throws {
        let configurationFileURL = URL(
            fileURLWithPath: promptOptions.configFile.expandingTilde
        ).standardizedFileURL
        let runInput = PromptConsoleInput(
            configFilePath: promptOptions.configFile,
            toolsFileName: promptOptions.tools,
            includeTools: promptOptions.includeTools,
            excludeTools: promptOptions.excludeTools,
            contextArgument: promptOptions.contextArgument,
            cannedContexts: promptOptions.cannedContexts,
            explicitMessages: promptOptions.messages.promptMessages,
            modelOverride: promptOptions.model,
            apiOverride: promptOptions.apiSelection?.configValue
        )
        let run = try PromptConsoleBuilder(input: runInput).build()
        let fileManager = FileManager.default
        let toolFactory = ToolFactory(
            fileManager: fileManager,
            toolsFileName: run.toolsFileName
        )
        let subAgentSessionState = SubAgentSessionState()
        let subAgentToolFactory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: SystemCredentialSource()
        )
        let supervisorHintSection = try subAgentToolFactory.supervisorHintSection(
            configurationFileURL: configurationFileURL
        )
        let runner = PromptConsoleRunner(
            config: run.config,
            toolProvider: {
                let shellTools = try toolFactory.makeTools(
                    config: run.config,
                    includeTools: run.includeTools,
                    excludeTools: run.excludeTools
                )
                let subAgentTools = try subAgentToolFactory.makeTools(
                    configurationFileURL: configurationFileURL,
                    toolsFileName: run.toolsFileName,
                    sessionState: subAgentSessionState,
                    modelOverride: run.modelOverride,
                    apiOverride: run.apiOverride,
                    includeTools: run.includeTools,
                    excludeTools: run.excludeTools
                )
                return shellTools + subAgentTools
            },
            modelOverride: run.modelOverride,
            apiOverride: run.apiOverride,
            interactive: interactive,
            standardInputHandler: run.standardInputHandler
        )
        let initialMessages = insertSupervisorHintMessage(
            supervisorHint: supervisorHintSection,
            into: run.initialMessages
        )
        try await runner.run(initialMessages: initialMessages)
    }
}
