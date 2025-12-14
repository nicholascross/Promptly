import ArgumentParser
import Foundation
import PromptlyKitTooling

// Configuration options for the tools subcommands.
struct ToolConfigOptions: ParsableArguments {
    @Option(
        name: .customLong("config-file"),
        help: "Specify a tools config file, disabling local/global discovery."
    )
    var configFile: String?
}
