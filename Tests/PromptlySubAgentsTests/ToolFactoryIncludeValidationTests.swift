import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import Testing

struct ToolFactoryIncludeValidationTests {
    @Test
    func throwsWhenIncludeFilterMatchesNoTools() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configFileURL)
        let config = try Config.loadConfig(
            url: configFileURL,
            fileManager: fileManager,
            credentialSource: credentialSource
        )

        let toolsConfigURL = fileManager.currentDirectoryURL.appendingPathComponent("tools.json")
        let emptySchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [:],
            description: nil
        )
        let shellCommandConfig = ShellCommandConfig(shellCommands: [
            ShellCommandConfigEntry(
                name: "AlphaTool",
                description: "Alpha tool for testing.",
                executable: "/usr/bin/true",
                echoOutput: nil,
                truncateOutput: nil,
                argumentTemplate: [["--version"]],
                exclusiveArgumentTemplate: nil,
                optIn: nil,
                parameters: emptySchema
            )
        ])
        try fileManager.writeShellCommandConfig(shellCommandConfig, to: toolsConfigURL)

        let toolFactory = ToolFactory(
            fileManager: fileManager,
            defaultToolsConfigURL: toolsConfigURL,
            localToolsConfigURL: toolsConfigURL
        )

        do {
            _ = try toolFactory.makeTools(
                config: config,
                includeTools: ["Beta"],
                excludeTools: [],
                toolOutput: { _ in }
            )
            Issue.record("Expected include filter validation error.")
        } catch let error as ToolFactoryError {
            switch error {
            case let .includeFilterMatchesNoTools(filter):
                #expect(filter == "Beta")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
