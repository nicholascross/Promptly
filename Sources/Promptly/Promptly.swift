import ArgumentParser
import Foundation

@main
struct Promptly: AsyncParsableCommand {

    static let configuration = CommandConfiguration(
        commandName: "promptly",
        abstract: "Promptly CLI for AI assistance and tool management",
        version: "__VERSION__",
        subcommands: [
            PromptCommand.self,
            UserInterfaceCommand.self,
            ToolCommand.self,
            AgentCommand.self,
            CannedCommand.self,
            TokenCommand.self
        ],
        defaultSubcommand: PromptCommand.self
    )
}
