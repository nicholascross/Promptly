import ArgumentParser
import Foundation
import PromptlyKit
import PromptlyKitTooling

/// `promptly tool list` — list all tools in a simple table
struct ToolList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all registered tools"
    )

    @OptionGroup
    var options: ToolConfigOptions

    func run() throws {
        let entries = try ToolFactory().loadConfigEntries(overrideConfigFile: options.configFile)
        guard !entries.isEmpty else {
            print("no tools registered")
            return
        }
        // Compute column widths
        let nameColumnWidth = max(entries.map { $0.name.count }.max() ?? 0, "ID".count)
        let executableColumnWidth = max(entries.map { $0.executable.count }.max() ?? 0, "Executable".count)

        // Print header with padded columns
        let headerName = "ID".padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
        let headerExecutable = "Executable".padding(toLength: executableColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerName)  \(headerExecutable)  Description")
        for entry in entries {
            let name = entry.name.padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
            let executable = entry.executable.padding(toLength: executableColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(executable)  \(entry.description)")
        }
    }
}
