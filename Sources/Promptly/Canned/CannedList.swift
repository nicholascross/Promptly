import ArgumentParser
import Foundation
import PromptlyAssets
import PromptlyKitUtils

/// `promptly canned list` - list available canned prompts
struct CannedList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available canned prompts"
    )

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let userEntries = try loadUserEntries(fileManager: fileManager)
        let bundledEntries = loadBundledEntries(
            existingNames: Set(userEntries.map { $0.name.lowercased() })
        )
        let entries = (userEntries + bundledEntries).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        guard !entries.isEmpty else {
            print("no canned prompts available")
            return
        }

        let nameColumnWidth = max(entries.map { $0.name.count }.max() ?? 0, "Name".count)
        let sourceColumnWidth = max(entries.map { $0.source.count }.max() ?? 0, "Source".count)
        let headerName = "Name".padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
        let headerSource = "Source".padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerName)  \(headerSource)")
        for entry in entries {
            let name = entry.name.padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
            let source = entry.source.padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(source)")
        }
    }
}

private struct CannedListEntry {
    let name: String
    let source: String
}

private extension CannedList {
    func loadUserEntries(fileManager: FileManagerProtocol) throws -> [CannedListEntry] {
        let baseDirectory = "~/.config/promptly/canned".expandingTilde
        guard fileManager.directoryExists(atPath: baseDirectory) else {
            return []
        }

        let directoryURL = URL(fileURLWithPath: baseDirectory, isDirectory: true)
        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "txt" }
        .sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        return urls.map { url in
            CannedListEntry(
                name: url.deletingPathExtension().lastPathComponent,
                source: "user"
            )
        }
    }

    func loadBundledEntries(existingNames: Set<String>) -> [CannedListEntry] {
        let loader = BundledResourceLoader()
        let names = loader.listResources(
            subdirectory: BundledDefaultAssetPaths.cannedPrompts,
            fileExtension: "txt"
        )
        return names
            .filter { !existingNames.contains($0.lowercased()) }
            .map { CannedListEntry(name: $0, source: "bundled") }
    }
}
