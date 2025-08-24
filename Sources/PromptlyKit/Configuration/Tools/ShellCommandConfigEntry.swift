import Foundation

public struct ShellCommandConfigEntry: Codable {
    public let name: String
    public let description: String
    public let executable: String
    /// Whether to echo the output of the command to the console.
    public let echoOutput: Bool?
    /// Whether to truncate large outputs of the command by slicing logs when enabled in tool config.
    public let truncateOutput: Bool?
    /// Groups of tokens to build each command segment.
    /// Each subarray may include placeholders (e.g. "{{param}}" or "p{{path}}");
    /// if any placeholder in a group has no corresponding value, the entire group is omitted.
    public let argumentTemplate: [[String]]
    /// When true, only the first argumentTemplate group whose placeholders can be fully resolved is used.
    public let exclusiveArgumentTemplate: Bool?
    /// When true, tool is disabled by default and only loaded when its name is specified via --include-tools.
    public let optIn: Bool?
    public let parameters: JSONSchema

    public init(
        name: String,
        description: String,
        executable: String,
        echoOutput: Bool?,
        truncateOutput: Bool?,
        argumentTemplate: [[String]],
        exclusiveArgumentTemplate: Bool?,
        optIn: Bool?,
        parameters: JSONSchema
    ) {
        self.name = name
        self.description = description
        self.executable = executable
        self.echoOutput = echoOutput
        self.truncateOutput = truncateOutput
        self.argumentTemplate = argumentTemplate
        self.exclusiveArgumentTemplate = exclusiveArgumentTemplate
        self.optIn = optIn
        self.parameters = parameters
    }
}
