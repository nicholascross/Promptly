import ArgumentParser
import Foundation
import PromptlyKitUtils

/// `promptly agent remove` - remove an agent configuration
struct AgentRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove an agent"
    )

    @Argument(help: "Name of the agent configuration to remove")
    var name: String

    @Flag(name: .customLong("force"), help: "Do not prompt for confirmation")
    var force: Bool = false

    @OptionGroup
    var options: AgentConfigOptions

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let agentConfigurationURL = options.agentConfigurationURL(agentName: name)

        guard fileManager.fileExists(atPath: agentConfigurationURL.path) else {
            FileHandle.standardError.write(Data("agent \(name) not found\n".utf8))
            throw ExitCode(3)
        }

        if !force {
            print("Remove agent '\(name)'? [y/N]: ", terminator: "")
            if readLine()?.lowercased() != "y" {
                return
            }
        }

        try fileManager.removeItem(atPath: agentConfigurationURL.path)
    }
}
