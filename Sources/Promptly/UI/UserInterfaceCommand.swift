import ArgumentParser
import Foundation
import PromptlyConsole
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import PromptlySubAgents

struct UserInterfaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ui",
        abstract: "Launch the terminal-based user interface"
    )

    @OptionGroup
    var promptOptions: PromptOptions

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
        let subAgentToolFactory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: SystemCredentialSource()
        )
        let supervisorHintSection = try subAgentToolFactory.supervisorHintSection(
            configurationFileURL: configurationFileURL
        )
        let toolProvider: (@escaping @Sendable (String) -> Void) throws -> [any ExecutableTool] = { toolOutput in
            let shellTools = try toolFactory.makeTools(
                config: run.config,
                includeTools: run.includeTools,
                excludeTools: run.excludeTools,
                toolOutput: toolOutput
            )
            let subAgentTools = try subAgentToolFactory.makeTools(
                configurationFileURL: configurationFileURL,
                toolsFileName: run.toolsFileName,
                modelOverride: run.modelOverride,
                apiOverride: run.apiOverride,
                includeTools: run.includeTools,
                excludeTools: run.excludeTools,
                toolOutput: toolOutput
            )
            return subAgentTools + shellTools
        }
        let runner = await PromptTerminalUIRunner(
            config: run.config,
            toolProvider: toolProvider,
            modelOverride: run.modelOverride,
            apiOverride: run.apiOverride,
            standardInputHandler: run.standardInputHandler
        )
        let initialMessages = insertSupervisorHintMessage(
            supervisorHint: supervisorHintSection,
            into: run.initialMessages
        )
        try await runner.run(initialMessages: initialMessages)
    }
}
