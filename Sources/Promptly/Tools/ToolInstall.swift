import ArgumentParser
import Foundation
import PromptlyKit

/// `promptly tool install` — install the default set of shell-command tools into the config directory
struct ToolInstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install default shell-command tools into the configuration directory"
    )

    @Option(
        name: .customLong("tools"),
        help: "Override the default shell command tools config basename (without .json)."
    )
    var tools: String = "tools"

    func run() throws {
        try Config.setupTools(toolsName: tools)
    }
}
