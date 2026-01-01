import ArgumentParser
import Foundation
import PromptlyAssets
import PromptlyKitUtils

/// `promptly agent view <name>` - show details for one agent
struct AgentView: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show details for a specific agent"
    )

    @Argument(help: "Name of the agent configuration to view")
    var name: String

    @OptionGroup
    var options: AgentConfigOptions

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let agentConfigurationURL = options.agentConfigurationURL(agentName: name)
        let bundledAgentIdentifier = options.agentIdentifier(agentName: name).lowercased()

        let agentDocument: JSONValue
        if fileManager.fileExists(atPath: agentConfigurationURL.path) {
            agentDocument = try loadJSONValue(from: agentConfigurationURL, fileManager: fileManager)
        } else if let bundledDocument = try loadBundledAgentDocument(
            agentIdentifier: bundledAgentIdentifier
        ) {
            FileHandle.standardError.write(Data("source: bundled\n".utf8))
            agentDocument = bundledDocument
        } else {
            FileHandle.standardError.write(Data("agent \(name) not found\n".utf8))
            throw ExitCode(3)
        }

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(agentDocument)
        if let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    private func loadJSONValue(from url: URL, fileManager: FileManagerProtocol) throws -> JSONValue {
        let data = try fileManager.readData(at: url)
        return try loadJSONValue(from: data, sourceURL: url)
    }

    private func loadJSONValue(from data: Data, sourceURL: URL) throws -> JSONValue {
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object = value else {
            throw AgentViewError.invalidRootValue(sourceURL)
        }
        return value
    }

    private func loadBundledAgentDocument(agentIdentifier: String) throws -> JSONValue? {
        let bundledAgents = BundledAgentDefaults()
        guard let data = bundledAgents.agentData(name: agentIdentifier),
              let url = bundledAgents.agentURL(name: agentIdentifier) else {
            return nil
        }
        return try loadJSONValue(from: data, sourceURL: url)
    }

}

private enum AgentViewError: Error, LocalizedError {
    case invalidRootValue(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidRootValue(url):
            return "Configuration at \(url.path) must be a JSON object."
        }
    }
}
