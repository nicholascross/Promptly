import Foundation
@testable import PromptlySubAgents
import Testing

struct SubAgentToolFactoryMakeToolTests {
    @Test
    func makeToolOverloadsProduceEquivalentToolMetadata() throws {
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
            systemPrompt: "You review changes."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("review.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)
        let agentData = try fileManager.readData(at: agentFileURL)

        let factory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: credentialSource
        )

        let toolFromURL = try factory.makeTool(
            configurationFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL,
            toolsFileName: "tools"
        )
        let toolFromData = try factory.makeTool(
            configurationFileURL: configurationFileURL,
            agentConfigurationData: agentData,
            agentSourceURL: agentFileURL,
            toolsFileName: "tools"
        )

        #expect(toolFromURL.name == "SubAgent-review-agent")
        #expect(toolFromData.name == toolFromURL.name)
        #expect(toolFromData.description == toolFromURL.description)
    }
}
