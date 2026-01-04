import Foundation
@testable import PromptlySubAgents
import PromptlyKit
import Testing

struct SubAgentSupervisorHintTests {
    @Test
    func returnsNilWhenNoAgentConfigurationsExist() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let factory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: credentialSource
        )

        let hintSection = try factory.supervisorHintSection(
            configurationFileURL: configurationFileURL
        )

        #expect(hintSection == nil)
    }

    @Test
    func returnsNilWhenAgentsHaveNoSupervisorHints() throws {
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

        let factory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: credentialSource
        )

        let hintSection = try factory.supervisorHintSection(
            configurationFileURL: configurationFileURL
        )

        #expect(hintSection == nil)
    }

    @Test
    func returnsSupervisorHintSectionWhenHintIsAvailable() throws {
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

        let factory = SubAgentToolFactory(
            fileManager: fileManager,
            credentialSource: credentialSource
        )

        let hintSection = try factory.supervisorHintSection(
            configurationFileURL: configurationFileURL
        )

        let expected = """
        Available sub agents (call tools by name when helpful):
        Prefer a matching sub agent over a shell tool when both can handle the request.
        - SubAgent-review-agent: Use when you need a focused review of proposed changes.

        When a sub agent returns needsMoreInformation or needsSupervisorDecision, gather the requested input or decision from the user.
        Then call the same sub agent tool again with the resumeId, and include the user's answers in the task or context pack notes.
        """

        #expect(hintSection == expected)
    }
}
