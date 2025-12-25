import Foundation
@testable import PromptlySubAgents
import PromptlyKit
import Testing

struct SubAgentConfigurationLoaderTests {
    @Test
    func discoversAgentConfigurationURLsSortedAndFiltered() throws {
        let fileManager = InMemoryFileManager()
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let firstAgentURL = agentsDirectoryURL.appendingPathComponent("b.json")
        let secondAgentURL = agentsDirectoryURL.appendingPathComponent("a.json")
        let ignoredURL = agentsDirectoryURL.appendingPathComponent("notes.txt")

        _ = fileManager.createFile(atPath: firstAgentURL.path, contents: Data(), attributes: nil)
        _ = fileManager.createFile(atPath: secondAgentURL.path, contents: Data(), attributes: nil)
        _ = fileManager.createFile(atPath: ignoredURL.path, contents: Data(), attributes: nil)

        let loader = SubAgentConfigurationLoader(fileManager: fileManager)
        let urls = try loader.discoverAgentConfigurationURLs(configFileURL: configurationFileURL)

        #expect(urls.map { $0.lastPathComponent } == ["a.json", "b.json"])
    }

    @Test
    func inheritsBaseConfigurationValuesWhenAgentDoesNotOverride() throws {
        try withTestTokenEnvironment {
            let fileManager = InMemoryFileManager()
            let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
            let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
            try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

            let baseConfiguration = makeBaseConfigurationJSON(
                model: "base-model",
                modelAliases: ["base": "base-model"]
            )
            try writeJSONValue(baseConfiguration, to: configurationFileURL, fileManager: fileManager)

            let agentConfiguration = makeAgentConfigurationJSON(
                name: "Review Agent",
                description: "Review changes and report issues.",
                systemPrompt: "You review changes."
            )
            let agentFileURL = agentsDirectoryURL.appendingPathComponent("review.json")
            try writeJSONValue(agentConfiguration, to: agentFileURL, fileManager: fileManager)

            let loader = SubAgentConfigurationLoader(fileManager: fileManager)
            let configuration = try loader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentFileURL
            )

            #expect(configuration.configuration.model == "base-model")
            #expect(configuration.configuration.modelAliases["base"] == "base-model")
            #expect(configuration.definition.name == "Review Agent")
            #expect(configuration.definition.description == "Review changes and report issues.")
        }
    }
}
