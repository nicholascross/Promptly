import ArgumentParser
import Foundation
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
        let fileManager = FileManager.default
        let agentsDirectoryURL = options.agentsDirectoryURL()

        guard fileManager.directoryExists(atPath: agentsDirectoryURL.path) else {
            print("no sub agents registered")
            return
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

        guard !agentURLs.isEmpty else {
            print("no sub agents registered")
            return
        }

        let entries = try agentURLs.map { url -> AgentListEntry in
            let data = try fileManager.readData(at: url)
            let document = try JSONDecoder().decode(AgentSummaryDocument.self, from: data)
            let identifier = url.deletingPathExtension().lastPathComponent
            return AgentListEntry(name: identifier, description: document.agent.description)
        }

        let nameColumnWidth = max(entries.map { $0.name.count }.max() ?? 0, "Name".count)
        let headerName = "Name".padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerName)  Description")
        for entry in entries {
            let name = entry.name.padding(toLength: nameColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(entry.description)")
        }
    }
}

private struct AgentListEntry {
    let name: String
    let description: String
}

private struct AgentSummaryDocument: Decodable {
    let agent: AgentSummary
}

private struct AgentSummary: Decodable {
    let name: String
    let description: String
}
