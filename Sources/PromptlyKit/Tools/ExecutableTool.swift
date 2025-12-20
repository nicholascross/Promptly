import Foundation

/// A protocol for defining a function-call (tool) available to the LLM.
public protocol ExecutableTool {
    /// The unique name of the tool.
    var name: String { get }
    /// A brief description of what the tool does.
    var description: String { get }
    /// The parameters schema as a `JSONSchema`.
    var parameters: JSONSchema { get }
    /// Execute the tool with the provided arguments (parsed into `JSONValue`). Returns a `JSONValue` result.
    func execute(arguments: JSONValue) async throws -> JSONValue
}

public extension [ExecutableTool] {
    func executeTool(
        name: String,
        arguments: JSONValue
    ) async throws -> JSONValue {
        guard let tool = tool(named: name) else { return .null }
        return try await tool.execute(arguments: arguments)
    }

    private func tool(named name: String) -> (any ExecutableTool)? {
        first { $0.name == name }
    }
}

