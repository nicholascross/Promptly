import Foundation
@testable import Promptly
import Testing

struct AgentRunCommandBehaviorTests {
    @Test
    func missingAgentConfigurationValidationThrowsExpectedError() async throws {
        try await withTemporaryAgentRunConfiguration { configurationFileURL, _ in
            let missingAgentName = "phase-nine-missing-agent-\(UUID().uuidString.lowercased())"
            let missingAgentConfigurationURL = configurationFileURL
                .deletingLastPathComponent()
                .appendingPathComponent("agents", isDirectory: true)
                .appendingPathComponent("\(missingAgentName).json")

            do {
                _ = try AgentRun.resolveAgentConfigurationSource(
                    fileManager: FileManager.default,
                    agentConfigurationURL: missingAgentConfigurationURL,
                    bundledAgentData: nil,
                    bundledAgentURL: nil
                )
                Issue.record("Expected missing agent configuration error.")
            } catch {
                #expect(error.localizedDescription.contains("Agent configuration not found at"))
                #expect(error.localizedDescription.contains("\(missingAgentName).json"))
            }
        }
    }

    @Test
    func missingReturnPayloadValidationThrowsExpectedError() throws {
        do {
            _ = try AgentRunResultPayloadValidator.requirePayload(
                nil,
                toolName: "SubAgent-review-agent"
            )
            Issue.record("Expected missing return payload validation to throw.")
        } catch {
            #expect(
                error.localizedDescription ==
                    "Supervisor did not call the SubAgent-review-agent tool."
            )
        }
    }

    private func withTemporaryAgentRunConfiguration(
        _ body: (URL, String) async throws -> Void
    ) async throws {
        let fileManager = FileManager.default
        let temporaryDirectoryURL = fileManager.temporaryDirectory.appendingPathComponent(
            "promptly-phase-nine-\(UUID().uuidString.lowercased())",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: temporaryDirectoryURL,
            withIntermediateDirectories: true
        )
        defer {
            try? fileManager.removeItem(at: temporaryDirectoryURL)
        }

        let configurationFileURL = temporaryDirectoryURL.appendingPathComponent("config.json")
        let tokenEnvironmentKey = "PROMPTLY_PHASE_NINE_TEST_TOKEN"
        let configurationJSONObject: [String: Any] = [
            "model": "test-model",
            "api": "responses",
            "provider": "test",
            "providers": [
                "test": [
                    "name": "Test",
                    "baseURL": "http://localhost:8000",
                    "envKey": tokenEnvironmentKey
                ]
            ]
        ]
        let configurationData = try JSONSerialization.data(
            withJSONObject: configurationJSONObject,
            options: [.sortedKeys]
        )
        try configurationData.write(to: configurationFileURL)

        try await body(configurationFileURL, tokenEnvironmentKey)
    }
}
