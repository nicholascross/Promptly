import ArgumentParser
import Foundation
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
        let toolFactory = ToolFactory(toolsFileName: session.toolsFileName)
        let subAgentToolFactory = SubAgentToolFactory()
        let runner = PromptCommandLineRunner(
            config: session.config,
            toolProvider: {
                let shellTools = try toolFactory.makeTools(
                    config: session.config,
                    includeTools: session.includeTools,
                    excludeTools: session.excludeTools
                )
                let subAgentTools = try subAgentToolFactory.makeTools(
                    configurationFileURL: configurationFileURL
                )
                return shellTools + subAgentTools
            },
            modelOverride: session.modelOverride,
            apiOverride: session.apiOverride,
            interactive: interactive,
            standardInputHandler: session.standardInputHandler
        )
        try await runner.run(initialMessages: session.initialMessages)
    }
}
