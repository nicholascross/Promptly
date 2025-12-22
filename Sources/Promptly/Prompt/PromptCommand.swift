import ArgumentParser
import PromptlyKit
import PromptlyKitTooling

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
        let runner = PromptCommandLineRunner(
            config: session.config,
            toolProvider: {
                try toolFactory.makeTools(
                    config: session.config,
                    includeTools: session.includeTools,
                    excludeTools: session.excludeTools
                )
            },
            modelOverride: session.modelOverride,
            apiOverride: session.apiOverride,
            interactive: interactive,
            standardInputHandler: session.standardInputHandler
        )
        try await runner.run(initialMessages: session.initialMessages)
    }
}
