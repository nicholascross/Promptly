import Foundation
@testable import PromptlySubAgents
import PromptlyKit
import PromptlyKitUtils
import Testing

struct SubAgentConfigurationLoaderTests {
    @Test
    func discoversAgentConfigurationURLsSortedAndFiltered() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let firstAgentURL = agentsDirectoryURL.appendingPathComponent("b.json")
        let secondAgentURL = agentsDirectoryURL.appendingPathComponent("a.json")
        let ignoredURL = agentsDirectoryURL.appendingPathComponent("notes.txt")

        _ = fileManager.createFile(atPath: firstAgentURL.path, contents: Data(), attributes: nil)
        _ = fileManager.createFile(atPath: secondAgentURL.path, contents: Data(), attributes: nil)
        _ = fileManager.createFile(atPath: ignoredURL.path, contents: Data(), attributes: nil)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let urls = try loader.discoverAgentConfigurationURLs(configFileURL: configurationFileURL)

        #expect(urls.map { $0.lastPathComponent } == ["a.json", "b.json"])
    }

    @Test
    func inheritsBaseConfigurationValuesWhenAgentDoesNotOverride() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(
            model: "base-model",
            modelAliases: ["base": "base-model"]
        )
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Review Agent",
            description: "Review changes and report issues.",
            systemPrompt: "You review changes."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("review.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        #expect(configuration.configuration.model == "base-model")
        #expect(configuration.configuration.modelAliases["base"] == "base-model")
        #expect(configuration.definition.name == "Review Agent")
        #expect(configuration.definition.description == "Review changes and report issues.")
    }

    @Test
    func decodesSupervisorHintWhenPresent() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Review Agent",
            description: "Review changes and report issues.",
            supervisorHint: "Use when you need a focused review of proposed changes.",
            systemPrompt: "You review changes."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("review.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        #expect(configuration.definition.supervisorHint == "Use when you need a focused review of proposed changes.")
    }

    @Test
    func ignoresEmptyStringOverridesForModelAndProvider() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration: JSONValue = .object([
            "model": .string(""),
            "provider": .string(""),
            "agent": .object([
                "name": .string("Release Notes"),
                "description": .string("Build release notes."),
                "systemPrompt": .string("Summarize release notes.")
            ])
        ])
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("release-notes.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        #expect(configuration.configuration.model == "base-model")
        #expect(configuration.definition.name == "Release Notes")
    }
}
