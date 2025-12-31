import Foundation
import PromptlyKitUtils

let testTokenEnvironmentKey = "PROMPTLY_TEST_TOKEN"

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
    supervisorHint: String? = nil,
    systemPrompt: String,
    model: String? = nil,
    tools: JSONValue? = nil
) -> JSONValue {
    var agentObject: [String: JSONValue] = [
        "name": .string(name),
        "description": .string(description),
        "systemPrompt": .string(systemPrompt)
    ]
    if let supervisorHint {
        agentObject["supervisorHint"] = .string(supervisorHint)
    }
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
