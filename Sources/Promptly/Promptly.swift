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
            ToolCommand.self,
            CannedCommand.self
        ],
        defaultSubcommand: PromptCommand.self
    )
}
