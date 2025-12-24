import Foundation
import PromptlyKit

public struct SubAgentToolFactory {
    private let configurationLoader: SubAgentConfigurationLoader

    public init(fileManager: FileManager = .default) {
        configurationLoader = SubAgentConfigurationLoader(fileManager: fileManager)
    }

    public func makeTools(
        configurationFileURL: URL,
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> [any ExecutableTool] {
        let agentURLs = try configurationLoader.discoverAgentConfigurationURLs(
            configFileURL: configurationFileURL
        )

        var tools: [any ExecutableTool] = []
        tools.reserveCapacity(agentURLs.count)

        for agentURL in agentURLs {
            let agentConfiguration = try configurationLoader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentURL
            )

            let agentName = agentConfiguration.definition.name
            let toolName = toolName(for: agentName)
            let description = agentConfiguration.definition.description
            let tool = SubAgentTool(
                name: toolName,
                description: description,
                executeHandler: { _ in
                    toolOutput("[sub-agent:\(agentName)] Execution not available yet.\n")
                    throw SubAgentToolError.executionUnavailable(agentName: agentName)
                }
            )

            tools.append(tool)
        }

        return tools
    }

    private func toolName(for agentName: String) -> String {
        "SubAgent.\(normalizedIdentifier(from: agentName))"
    }

    private func normalizedIdentifier(from agentName: String) -> String {
        let trimmed = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")

        var normalized = ""
        var previousWasSeparator = false
        for scalar in lowered.unicodeScalars {
            if allowedCharacters.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                normalized.append("-")
                previousWasSeparator = true
            }
        }

        let trimmedSeparators = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmedSeparators.isEmpty ? "agent" : trimmedSeparators
    }
}
