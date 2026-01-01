import ArgumentParser
import Foundation
import PromptlyAssets
import PromptlyKitUtils

/// `promptly agent list` - list all configured agents in a simple table
struct AgentList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available sub agents"
    )

    @OptionGroup
    var options: AgentConfigOptions

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let agentsDirectoryURL = options.agentsDirectoryURL()

        let userEntries = try loadUserEntries(
            fileManager: fileManager,
            agentsDirectoryURL: agentsDirectoryURL
        )
        let bundledEntries = try loadBundledEntries(
            existingNames: Set(userEntries.map { $0.name.lowercased() })
        )

        let entries = (userEntries + bundledEntries).sorted {
            $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }

        guard !entries.isEmpty else {
            print("no sub agents registered")
            return
        }

        let nameColumnWidth = max(entries.map { $0.name.count }.max() ?? 0, "Name".count)
        let sourceColumnWidth = max(entries.map { $0.source.count }.max() ?? 0, "Source".count)
        let headerName = "Name".padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
        let headerSource = "Source".padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerName)  \(headerSource)  Description")
        for entry in entries {
            let name = entry.name.padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
            let source = entry.source.padding(toLength: sourceColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(source)  \(entry.description)")
        }
    }
}

private struct AgentListEntry {
    let name: String
    let description: String
    let source: String
}

private struct AgentSummaryDocument: Decodable {
    let agent: AgentSummary
}

private struct AgentSummary: Decodable {
    let name: String
    let description: String
}

private extension AgentList {
    func loadUserEntries(
        fileManager: FileManagerProtocol,
        agentsDirectoryURL: URL
    ) throws -> [AgentListEntry] {
        guard fileManager.directoryExists(atPath: agentsDirectoryURL.path) else {
            return []
        }

        let agentURLs = try fileManager.contentsOfDirectory(
            at: agentsDirectoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        .filter { $0.pathExtension.lowercased() == "json" }
        .sorted {
            $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
        }

        return try agentURLs.map { url -> AgentListEntry in
            let data = try fileManager.readData(at: url)
            let document = try JSONDecoder().decode(AgentSummaryDocument.self, from: data)
            let identifier = url.deletingPathExtension().lastPathComponent
            return AgentListEntry(
                name: identifier,
                description: document.agent.description,
                source: "user"
            )
        }
    }

    func loadBundledEntries(
        existingNames: Set<String>
    ) throws -> [AgentListEntry] {
        let bundledAgents = BundledAgentDefaults()
        let bundledNames = bundledAgents.agentNames()
        guard !bundledNames.isEmpty else {
            return []
        }

        var entries: [AgentListEntry] = []
        entries.reserveCapacity(bundledNames.count)
        for name in bundledNames where !existingNames.contains(name.lowercased()) {
            guard let data = bundledAgents.agentData(name: name) else {
                continue
            }
            let document = try JSONDecoder().decode(AgentSummaryDocument.self, from: data)
            entries.append(
                AgentListEntry(
                    name: name,
                    description: document.agent.description,
                    source: "bundled"
                )
            )
        }
        return entries
    }
}
