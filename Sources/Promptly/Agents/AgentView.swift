import ArgumentParser
import Foundation
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
        let fileManager = FileManager.default
        let agentConfigurationURL = options.agentConfigurationURL(agentName: name)

        guard fileManager.fileExists(atPath: agentConfigurationURL.path) else {
            FileHandle.standardError.write(Data("agent \(name) not found\n".utf8))
            throw ExitCode(3)
        }

        let agentDocument = try loadJSONValue(from: agentConfigurationURL, fileManager: fileManager)

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(agentDocument)
        if let json = String(data: data, encoding: .utf8) {
            print(json)
        }
    }

    private func loadJSONValue(from url: URL, fileManager: FileManager) throws -> JSONValue {
        let data = try fileManager.readData(at: url)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        guard case .object = value else {
            throw AgentViewError.invalidRootValue(url)
        }
        return value
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
