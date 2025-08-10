import Foundation

struct ShellCommandConfigEntry: Decodable {
    let name: String
    let description: String
    let executable: String
    /// Whether to echo the output of the command to the console.
    let echoOutput: Bool?
    /// Whether to truncate large outputs of the command by slicing logs when enabled in tool config.
    let truncateOutput: Bool?
    /// Groups of tokens to build each command segment.
    /// Each subarray may include placeholders (e.g. "{{param}}" or "p{{path}}");
    /// if any placeholder in a group has no corresponding value, the entire group is omitted.
    let argumentTemplate: [[String]]
    /// When true, only the first argumentTemplate group whose placeholders can be fully resolved is used.
    let exclusiveArgumentTemplate: Bool?
    /// When true, tool is disabled by default and only loaded when its name is specified via --include-tools.
    let optIn: Bool?
    let parameters: JSONSchema
}
