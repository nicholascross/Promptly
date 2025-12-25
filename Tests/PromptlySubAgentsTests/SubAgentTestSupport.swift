import Foundation
import PromptlyKit
import PromptlyKitUtils

let testTokenEnvironmentKey = "PROMPTLY_TEST_TOKEN"

func withTestTokenEnvironment<T>(_ operation: () throws -> T) rethrows -> T {
    let existingValue = getenv(testTokenEnvironmentKey).map { String(cString: $0) }
    setenv(testTokenEnvironmentKey, "test-token", 1)
    defer {
        if let existingValue {
            setenv(testTokenEnvironmentKey, existingValue, 1)
        } else {
            unsetenv(testTokenEnvironmentKey)
        }
    }
    return try operation()
}

func withTestTokenEnvironment<T>(_ operation: () async throws -> T) async rethrows -> T {
    let existingValue = getenv(testTokenEnvironmentKey).map { String(cString: $0) }
    setenv(testTokenEnvironmentKey, "test-token", 1)
    defer {
        if let existingValue {
            setenv(testTokenEnvironmentKey, existingValue, 1)
        } else {
            unsetenv(testTokenEnvironmentKey)
        }
    }
    return try await operation()
}

func writeJSONValue(_ value: JSONValue, to url: URL, fileManager: FileManagerProtocol) throws {
    let data = try JSONEncoder().encode(value)
    try fileManager.writeData(data, to: url)
}

func writeShellCommandConfig(
    _ config: ShellCommandConfig,
    to url: URL,
    fileManager: FileManagerProtocol
) throws {
    let data = try JSONEncoder().encode(config)
    try fileManager.writeData(data, to: url)
}

func loadJSONLines(from url: URL, fileManager: FileManagerProtocol) throws -> [JSONValue] {
    let data = try fileManager.readData(at: url)
    let contents = String(decoding: data, as: UTF8.self)
    let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
    var entries: [JSONValue] = []
    entries.reserveCapacity(lines.count)
    for line in lines {
        let data = Data(line.utf8)
        let value = try JSONDecoder().decode(JSONValue.self, from: data)
        entries.append(value)
    }
    return entries
}

func makeBaseConfigurationJSON(model: String, modelAliases: [String: String] = [:]) -> JSONValue {
    var root: [String: JSONValue] = [
        "model": .string(model),
        "api": .string("responses"),
        "provider": .string("test"),
        "providers": .object([
            "test": .object([
                "name": .string("Test"),
                "baseURL": .string("http://localhost:8000"),
                "envKey": .string(testTokenEnvironmentKey)
            ])
        ])
    ]

    if !modelAliases.isEmpty {
        let aliases = Dictionary(uniqueKeysWithValues: modelAliases.map { key, value in
            (key, JSONValue.string(value))
        })
        root["modelAliases"] = .object(aliases)
    }

    return .object(root)
}

func makeAgentConfigurationJSON(
    name: String,
    description: String,
    systemPrompt: String,
    model: String? = nil,
    tools: JSONValue? = nil
) -> JSONValue {
    var agentObject: [String: JSONValue] = [
        "name": .string(name),
        "description": .string(description),
        "systemPrompt": .string(systemPrompt)
    ]
    if let tools {
        agentObject["tools"] = tools
    }

    var root: [String: JSONValue] = [
        "agent": .object(agentObject)
    ]

    if let model {
        root["model"] = .string(model)
    }

    return .object(root)
}

func objectValue(_ value: JSONValue?) -> [String: JSONValue]? {
    guard case let .object(object) = value else {
        return nil
    }
    return object
}

func stringValue(_ value: JSONValue?) -> String? {
    guard case let .string(text) = value else {
        return nil
    }
    return text
}
