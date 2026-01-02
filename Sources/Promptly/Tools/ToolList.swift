import ArgumentParser
import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils

/// `promptly tool list` — list all tools in a simple table
struct ToolList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List all registered tools"
    )

    @OptionGroup
    var options: ToolConfigOptions

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let entries = try ToolFactory(fileManager: fileManager)
            .loadConfigEntriesWithSources(overrideConfigFile: options.configFile)
        guard !entries.isEmpty else {
            print("no tools registered")
            return
        }
        // Compute column widths
        let nameColumnWidth = max(entries.map { $0.entry.name.count }.max() ?? 0, "ID".count)
        let sourceColumnWidth = max(entries.map { $0.source.rawValue.count }.max() ?? 0, "Source".count)
        let executableColumnWidth = max(entries.map { $0.entry.executable.count }.max() ?? 0, "Executable".count)

        // Print header with padded columns
        let headerName = "ID".padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
        let headerSource = "Source".padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
        let headerExecutable = "Executable".padding(toLength: executableColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerName)  \(headerSource)  \(headerExecutable)  Description")
        for entry in entries {
            let name = entry.entry.name.padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
            let source = entry.source.rawValue.padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
            let executable = entry.entry.executable.padding(toLength: executableColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(source)  \(executable)  \(entry.entry.description)")
        }
    }
}
