import ArgumentParser
import Foundation
import PromptlyKitUtils

// Configuration options for the agent subcommands.
struct AgentConfigOptions: ParsableArguments {
    @Option(
        name: [.customShort("c"), .customLong("config-file")],
        help: "Override the default configuration path of ~/.config/promptly/config.json."
    )
    var configurationFile: String = "~/.config/promptly/config.json"

    func configurationFileURL() -> URL {
        URL(fileURLWithPath: configurationFile.expandingTilde).standardizedFileURL
    }

    func agentsDirectoryURL() -> URL {
        configurationFileURL()
            .deletingLastPathComponent()
            .appendingPathComponent("agents", isDirectory: true)
    }

    func agentConfigurationURL(agentName: String) -> URL {
        agentsDirectoryURL()
            .appendingPathComponent(normalizedAgentFileName(agentName), isDirectory: false)
    }

    private func normalizedAgentFileName(_ agentName: String) -> String {
        if agentName.hasSuffix(".json") {
            return agentName
        }
        return "\(agentName).json"
    }
}
