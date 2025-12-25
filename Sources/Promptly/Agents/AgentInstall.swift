import ArgumentParser
import Foundation
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
        let fileManager = FileManager.default
        let agentsDirectoryURL = options.agentsDirectoryURL()
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true)

        guard !DefaultAgentConfigurations.configurations.isEmpty else {
            print("no default agents available")
            return
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        for entry in DefaultAgentConfigurations.configurations {
            let fileURL = agentsDirectoryURL.appendingPathComponent("\(entry.fileName).json")
            if fileManager.fileExists(atPath: fileURL.path) {
                print("Skipped existing agent configuration at \(fileURL.path)")
                continue
            }
            let data = try encoder.encode(entry.configuration)
            try data.write(to: fileURL)
            print("Installed agent configuration to \(fileURL.path)")
        }
    }
}
