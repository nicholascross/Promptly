import Foundation
import PromptlyKitUtils

public protocol ToolExecutionGateway {
    func executeToolCall(name: String, arguments: JSONValue) async throws -> JSONValue
}

public struct ToolRegistryGateway: ToolExecutionGateway {
    private let tools: [any ExecutableTool]

    public init(tools: [any ExecutableTool]) {
        self.tools = tools
    }

    public func executeToolCall(name: String, arguments: JSONValue) async throws -> JSONValue {
        try await tools.executeTool(name: name, arguments: arguments)
    }
}
