import ArgumentParser
import Foundation
import PromptlyAssets
import PromptlyKitUtils

/// `promptly agent install` - install default agents into the config directory
struct AgentInstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install default sub agents into the configuration directory"
    )

    @OptionGroup
    var options: AgentConfigOptions

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let agentsDirectoryURL = options.agentsDirectoryURL()
        try fileManager.createDirectory(
            at: agentsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let bundledAgents = BundledAgentDefaults()
        let agentNames = bundledAgents.agentNames()
        guard !agentNames.isEmpty else {
            print("no default agents available")
            return
        }

        for name in agentNames {
            guard let data = bundledAgents.agentData(name: name) else {
                throw AgentInstallError.bundledDefaultsUnavailable
            }
            let fileURL = agentsDirectoryURL.appendingPathComponent("\(name).json")
            if fileManager.fileExists(atPath: fileURL.path) {
                print("Skipped existing agent configuration at \(fileURL.path)")
                continue
            }
            try fileManager.writeData(data, to: fileURL)
            print("Installed agent configuration to \(fileURL.path)")
        }
    }
}

private enum AgentInstallError: Error, LocalizedError {
    case bundledDefaultsUnavailable

    var errorDescription: String? {
        switch self {
        case .bundledDefaultsUnavailable:
            return "Bundled agent defaults are unavailable."
        }
    }
}
