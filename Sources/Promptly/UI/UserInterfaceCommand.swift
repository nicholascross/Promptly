import ArgumentParser
import Foundation
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
        let sessionInput = PromptSessionInput(
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
        let session = try PromptSessionBuilder(input: sessionInput).build()
        let fileManager = FileManager.default
        let defaultToolsConfigURL = ToolFactory.defaultToolsConfigURL(
            fileManager: fileManager,
            toolsFileName: session.toolsFileName
        )
        let localToolsConfigURL = ToolFactory.localToolsConfigURL(
            fileManager: fileManager,
            toolsFileName: session.toolsFileName
        )
        let toolFactory = ToolFactory(
            fileManager: fileManager,
            defaultToolsConfigURL: defaultToolsConfigURL,
            localToolsConfigURL: localToolsConfigURL
        )
        let subAgentToolFactory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: SystemCredentialSource()
        )
        let toolProvider: (@escaping @Sendable (String) -> Void) throws -> [any ExecutableTool] = { toolOutput in
            let shellTools = try toolFactory.makeTools(
                config: session.config,
                includeTools: session.includeTools,
                excludeTools: session.excludeTools,
                toolOutput: toolOutput
            )
            let subAgentTools = try subAgentToolFactory.makeTools(
                configurationFileURL: configurationFileURL,
                defaultToolsConfigURL: defaultToolsConfigURL,
                localToolsConfigURL: localToolsConfigURL,
                includeTools: session.includeTools,
                excludeTools: session.excludeTools,
                toolOutput: toolOutput
            )
            return shellTools + subAgentTools
        }
        let runner = await PromptTerminalUIRunner(
            config: session.config,
            toolProvider: toolProvider,
            modelOverride: session.modelOverride,
            apiOverride: session.apiOverride,
            standardInputHandler: session.standardInputHandler
        )
        try await runner.run(initialMessages: session.initialMessages)
    }
}
