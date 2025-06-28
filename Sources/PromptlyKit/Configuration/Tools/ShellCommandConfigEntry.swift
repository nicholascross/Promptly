import Foundation

struct ShellCommandConfigEntry: Decodable {
    let name: String
    let description: String
    let executable: String
    /// Groups of tokens to build each command segment.
    /// Each subarray may include placeholders (e.g. "{{param}}" or "p{{path}}");
    /// if any placeholder in a group has no corresponding value, the entire group is omitted.
    let argumentTemplate: [[String]]
    let parameters: JSONSchema
}
