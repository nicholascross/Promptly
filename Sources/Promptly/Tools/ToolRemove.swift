import ArgumentParser
import Foundation
import PromptlyKit
import PromptlyKitTooling

/// `promptly tool remove` — remove a tool from the registry
struct ToolRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a tool"
    )

    @Argument(help: "ID of the tool to remove")
    var id: String
    @Flag(name: .customLong("force"), help: "Do not prompt for confirmation")
    var force: Bool = false
    @OptionGroup
    var options: ToolConfigOptions

    func run() throws {
        let url = ToolFactory().toolsConfigURL(options.configFile)
        let fileManager = FileManager()
        // Load config
        guard
            let data = try? Data(contentsOf: url),
            var config = try? JSONDecoder().decode(ShellCommandConfig.self, from: data)
        else {
            FileHandle.standardError.write(Data("tool \(id) not found\n".utf8))
            throw ExitCode(3)
        }
        // Find tool index
        guard let index = config.shellCommands.firstIndex(where: { $0.name == id }) else {
            FileHandle.standardError.write(Data("tool \(id) not found\n".utf8))
            throw ExitCode(3)
        }
        // Confirm removal
        if !force {
            print("Remove tool '\(id)'? [y/N]: ", terminator: "")
            if readLine()?.lowercased() != "y" {
                return
            }
        }
        config.shellCommands.remove(at: index)
        // Persist updated config
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let outputData = try encoder.encode(config)
        try fileManager.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try outputData.write(to: url)
    }
}
