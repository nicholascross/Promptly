import ArgumentParser
import Foundation
import PromptlyKit

/// `promptly tool add` — add a new tool to the registry
struct ToolAdd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a new tool"
    )

    @OptionGroup
    var options: ToolConfigOptions
    @Option(name: .customLong("id"), help: "Unique identifier for the new tool")
    var id: String
    @Option(name: .customLong("name"), help: "Tool description")
    var name: String
    @Option(name: .customLong("command"), help: "Executable or command to run")
    var executable: String
    @Flag(name: .customLong("echo-output"), help: "Echo tool output to console")
    var echoOutput: Bool = false
    @Flag(name: .customLong("truncate-output"), help: "Truncate large outputs of the command")
    var truncateOutput: Bool = false
    @Flag(
        name: .customLong("exclusive-argument-template"),
        help: "Use only the first fully resolved argument template group"
    )
    var exclusiveArgumentTemplate: Bool = false
    @Option(
        name: .customLong("argument-template"),
        parsing: .singleValue,
        help: "Comma-separated list of tokens for one argument-template group; may be provided multiple times.",
        transform: { raw in raw.split(separator: ",").map(String.init) }
    )
    var argumentTemplate: [[String]] = []
    @Option(
        name: .customLong("parameters-file"),
        help: "Path to JSON schema file describing allowed parameters"
    )
    var parametersFile: String?
    @Option(
        name: .customLong("parameters"),
        help: "JSON schema string describing allowed parameters"
    )
    var parameters: String?
    @Flag(name: .customLong("opt-in"), help: "Disable tool by default, only load when explicitly included")
    var optIn: Bool = false

    func run() throws {
        let url = ToolFactory().toolsConfigURL(options.configFile)
        let fileManager = FileManager()
        // Load existing config or start fresh
        var config: ShellCommandConfig
        if
            let data = try? Data(contentsOf: url),
            let existing = try? JSONDecoder().decode(ShellCommandConfig.self, from: data)
        {
            config = existing
        } else {
            config = ShellCommandConfig(shellCommands: [])
        }
        // Check for duplicate ID
        if config.shellCommands.contains(where: { $0.name == id }) {
            FileHandle.standardError.write(Data("tool \(id) already exists\n".utf8))
            throw ExitCode(2)
        }
        // Build the parameters schema
        let parametersSchema: JSONSchema
        if let filePath = parametersFile {
            let data = try Data(contentsOf: URL(fileURLWithPath: filePath))
            parametersSchema = try JSONDecoder().decode(JSONSchema.self, from: data)
        } else if let params = parameters {
            let data = Data(params.utf8)
            parametersSchema = try JSONDecoder().decode(JSONSchema.self, from: data)
        } else {
            parametersSchema = .object(requiredProperties: [:], optionalProperties: [:], description: nil)
        }

        // Create new entry
        let entry = ShellCommandConfigEntry(
            name: id,
            description: name,
            executable: executable,
            echoOutput: echoOutput,
            truncateOutput: truncateOutput,
            argumentTemplate: argumentTemplate,
            exclusiveArgumentTemplate: exclusiveArgumentTemplate,
            optIn: optIn,
            parameters: parametersSchema
        )

        config.shellCommands.append(entry)

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
