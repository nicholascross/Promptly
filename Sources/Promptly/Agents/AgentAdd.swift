import ArgumentParser
import Foundation
import PromptlyKitUtils

/// `promptly agent add` - add a new agent configuration
struct AgentAdd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new agent"
    )

    @Argument(help: "Name of the agent configuration file (without .json)")
    var name: String

    @OptionGroup
    var options: AgentConfigOptions

    @Option(name: .customLong("agent-name"), help: "Display name for the agent")
    var agentName: String?

    @Option(name: .customLong("description"), help: "Short description for the agent")
    var description: String

    @Option(name: .customLong("supervisor-hint"), help: "Short hint for when the supervisor should call this agent")
    var supervisorHint: String?

    @Option(name: .customLong("system-prompt"), help: "System prompt for the agent")
    var systemPrompt: String

    @Option(name: .customLong("model"), help: "Override the model for this agent")
    var model: String?

    @Option(name: .customLong("provider"), help: "Override the provider for this agent")
    var provider: String?

    @Option(name: .customLong("api"), help: "Override the API selection for this agent (responses or chat)")
    var apiSelection: APISelection?

    @Option(name: .customLong("tools-file-name"), help: "Override the tools file name for this agent")
    var toolsFileName: String?

    @Option(
        name: .customLong("include-tools"),
        help: "Include shell tools by name. Provide one or more substrings; only matching tools will be loaded."
    )
    var includeTools: [String] = []

    @Option(
        name: .customLong("exclude-tools"),
        help: "Exclude shell tools by name. Provide one or more substrings; any matching tools will be omitted."
    )
    var excludeTools: [String] = []

    @Flag(name: .customLong("force"), help: "Overwrite an existing agent configuration")
    var force: Bool = false

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let agentsDirectoryURL = options.agentsDirectoryURL()
        let agentConfigurationURL = options.agentConfigurationURL(agentName: name)

        if fileManager.fileExists(atPath: agentConfigurationURL.path), !force {
            FileHandle.standardError.write(Data("agent \(name) already exists\n".utf8))
            throw ExitCode(2)
        }

        let normalizedAgentName = normalizedOptionalString(agentName)
        let normalizedSupervisorHint = normalizedOptionalString(supervisorHint)
        let normalizedModel = normalizedOptionalString(model)
        let normalizedProvider = normalizedOptionalString(provider)
        let normalizedToolsFileName = normalizedOptionalString(toolsFileName)

        let includeOverrides = includeTools.isEmpty ? nil : includeTools
        let excludeOverrides = excludeTools.isEmpty ? nil : excludeTools
        let toolOverrides: AgentToolOverrides?
        if normalizedToolsFileName != nil || includeOverrides != nil || excludeOverrides != nil {
            toolOverrides = AgentToolOverrides(
                toolsFileName: normalizedToolsFileName,
                include: includeOverrides,
                exclude: excludeOverrides
            )
        } else {
            toolOverrides = nil
        }

        let document = AgentConfigurationDocument(
            model: normalizedModel,
            provider: normalizedProvider,
            api: apiString(from: apiSelection),
            agent: AgentDefinitionDocument(
                name: normalizedAgentName ?? name,
                description: description,
                supervisorHint: normalizedSupervisorHint,
                systemPrompt: systemPrompt,
                tools: toolOverrides
            )
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(document)
        try fileManager.createDirectory(
            at: agentsDirectoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )
        try fileManager.writeData(data, to: agentConfigurationURL)
    }

    private func normalizedOptionalString(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : value
    }

    private func apiString(from selection: APISelection?) -> String? {
        guard let selection else { return nil }
        switch selection {
        case .responses:
            return "responses"
        case .chatCompletions:
            return "chat"
        }
    }
}
