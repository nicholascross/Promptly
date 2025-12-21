import ArgumentParser
import PromptlyKit
import PromptlyKitTooling

struct UserInterfaceCommand: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "ui",
        abstract: "Launch the terminal-based user interface"
    )

    @OptionGroup
    var promptOptions: PromptOptions

    mutating func run() async throws {
        let sessionInput = PromptSessionInput(
            configFilePath: promptOptions.configFile,
            toolsFileName: promptOptions.tools,
            includeTools: promptOptions.includeTools,
            excludeTools: promptOptions.excludeTools,
            contextArgument: promptOptions.contextArgument,
            cannedContexts: promptOptions.cannedContexts,
            explicitMessages: promptOptions.messages.chatMessages,
            modelOverride: promptOptions.model,
            apiOverride: promptOptions.apiSelection?.configValue
        )
        let session = try PromptSessionBuilder(input: sessionInput).build()
        let toolFactory = ToolFactory(toolsFileName: session.toolsFileName)
        let runner = await PromptTerminalUIRunner(
            config: session.config,
            toolFactory: toolFactory,
            includeTools: session.includeTools,
            excludeTools: session.excludeTools,
            modelOverride: session.modelOverride,
            apiOverride: session.apiOverride,
            standardInputHandler: session.standardInputHandler
        )
        try await runner.run(initialMessages: session.initialMessages)
    }
}
