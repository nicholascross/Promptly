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
        let configEntries = try ToolFactory(fileManager: fileManager)
            .loadConfigEntriesWithSources(overrideConfigFile: options.configFile)
        let displayEntries = buildToolDisplayEntries(
            configEntries: configEntries,
            fileManager: fileManager
        )
        guard !displayEntries.isEmpty else {
            print("no tools registered")
            return
        }
        // Compute column widths
        let nameColumnWidth = max(displayEntries.map { $0.identifier.count }.max() ?? 0, "ID".count)
        let sourceColumnWidth = max(displayEntries.map { $0.source.count }.max() ?? 0, "Source".count)
        let executableColumnWidth = max(displayEntries.map { $0.executable.count }.max() ?? 0, "Executable".count)

        // Print header with padded columns
        let headerName = "ID".padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
        let headerSource = "Source".padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
        let headerExecutable = "Executable".padding(toLength: executableColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerName)  \(headerSource)  \(headerExecutable)  Description")
        for entry in displayEntries {
            let name = entry.identifier.padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
            let source = entry.source.padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
            let executable = entry.executable.padding(toLength: executableColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(source)  \(executable)  \(entry.description)")
        }
    }

    private struct ToolDisplayEntry {
        let identifier: String
        let source: String
        let executable: String
        let description: String
    }

    private func buildToolDisplayEntries(
        configEntries: [ToolConfigEntryWithSource],
        fileManager: FileManagerProtocol
    ) -> [ToolDisplayEntry] {
        var displayEntries = builtInToolDisplayEntries(fileManager: fileManager)
        var seenIdentifiers = Set(displayEntries.map { $0.identifier.lowercased() })

        for entry in configEntries {
            let identifier = entry.entry.name
            guard !seenIdentifiers.contains(identifier.lowercased()) else {
                continue
            }
            displayEntries.append(
                ToolDisplayEntry(
                    identifier: identifier,
                    source: entry.source.rawValue,
                    executable: entry.entry.executable,
                    description: entry.entry.description
                )
            )
            seenIdentifiers.insert(identifier.lowercased())
        }

        return displayEntries
    }

    private func builtInToolDisplayEntries(
        fileManager: FileManagerProtocol
    ) -> [ToolDisplayEntry] {
        let rootDirectory = URL(
            fileURLWithPath: fileManager.currentDirectoryPath,
            isDirectory: true
        )
        let applyPatchTool = ApplyPatchTool(
            rootDirectory: rootDirectory,
            output: { _ in }
        )

        return [
            ToolDisplayEntry(
                identifier: applyPatchTool.name,
                source: "built-in",
                executable: "built-in",
                description: summarizedDescription(applyPatchTool.description)
            )
        ]
    }

    private func summarizedDescription(_ description: String) -> String {
        let trimmed = description.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let periodIndex = trimmed.firstIndex(of: ".") else {
            return trimmed
        }
        return String(trimmed[...periodIndex])
    }
}
