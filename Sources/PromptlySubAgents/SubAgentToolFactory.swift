import Foundation
import PromptlyKit
import PromptlyKitUtils

public struct SubAgentToolFactory {
    private let configurationLoader: SubAgentConfigurationLoader
    private let fileManager: FileManagerProtocol

    public init(
        fileManager: FileManagerProtocol,
        credentialSource: CredentialSource
    ) {
        self.fileManager = fileManager
        configurationLoader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
    }

    public func makeTools(
        configurationFileURL: URL,
        defaultToolsConfigURL: URL,
        localToolsConfigURL: URL,
        sessionState: SubAgentSessionState,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> [any ExecutableTool] {
        let agentURLs = try configurationLoader.discoverAgentConfigurationURLs(
            configFileURL: configurationFileURL
        )
        let toolDefaults = SubAgentToolSettings(
            defaultToolsConfigURL: defaultToolsConfigURL.standardizedFileURL,
            localToolsConfigURL: localToolsConfigURL.standardizedFileURL,
            includeTools: includeTools,
            excludeTools: excludeTools
        )

        var tools: [any ExecutableTool] = []
        tools.reserveCapacity(agentURLs.count)

        for agentURL in agentURLs {
            let agentConfiguration = try configurationLoader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentURL
            )

            let tool = makeTool(
                agentConfiguration: agentConfiguration,
                configurationFileURL: configurationFileURL,
                toolDefaults: toolDefaults,
                sessionState: sessionState,
                modelOverride: modelOverride,
                apiOverride: apiOverride,
                toolOutput: toolOutput
            )
            tools.append(tool)
        }

        return tools
    }

    public func supervisorHintSection(
        configurationFileURL: URL
    ) throws -> String? {
        let agentURLs = try configurationLoader.discoverAgentConfigurationURLs(
            configFileURL: configurationFileURL
        )

        var hintLines: [String] = []
        hintLines.reserveCapacity(agentURLs.count)

        for agentURL in agentURLs {
            let agentConfiguration = try configurationLoader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentURL
            )
            guard let hint = normalizedSupervisorHint(
                agentConfiguration.definition.supervisorHint
            ) else {
                continue
            }
            let toolName = toolName(for: agentConfiguration.definition.name)
            hintLines.append("- \(toolName): \(hint)")
        }

        guard !hintLines.isEmpty else {
            return nil
        }

        let header = "Available sub agents (call tools by name when helpful):"
        return ([header] + hintLines).joined(separator: "\n")
    }

    public func makeTool(
        configurationFileURL: URL,
        agentConfigurationURL: URL,
        defaultToolsConfigURL: URL,
        localToolsConfigURL: URL,
        sessionState: SubAgentSessionState,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> any ExecutableTool {
        let toolDefaults = SubAgentToolSettings(
            defaultToolsConfigURL: defaultToolsConfigURL.standardizedFileURL,
            localToolsConfigURL: localToolsConfigURL.standardizedFileURL,
            includeTools: includeTools,
            excludeTools: excludeTools
        )
        let agentConfiguration = try configurationLoader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentConfigurationURL
        )
        return makeTool(
            agentConfiguration: agentConfiguration,
            configurationFileURL: configurationFileURL,
            toolDefaults: toolDefaults,
            sessionState: sessionState,
            modelOverride: modelOverride,
            apiOverride: apiOverride,
            toolOutput: toolOutput
        )
    }

    private func toolName(for agentName: String) -> String {
        "SubAgent-\(normalizedIdentifier(from: agentName))"
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

    private func normalizedSupervisorHint(_ hint: String?) -> String? {
        guard let hint else {
            return nil
        }
        let trimmed = hint.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }

    private func resolveToolSettings(
        defaults: SubAgentToolSettings,
        overrides: SubAgentToolConfiguration?
    ) -> SubAgentToolSettings {
        guard let overrides else {
            return defaults
        }

        let includeTools = overrides.include ?? defaults.includeTools
        let excludeTools = overrides.exclude ?? defaults.excludeTools

        guard let toolsFileName = overrides.toolsFileName else {
            return SubAgentToolSettings(
                defaultToolsConfigURL: defaults.defaultToolsConfigURL,
                localToolsConfigURL: defaults.localToolsConfigURL,
                includeTools: includeTools,
                excludeTools: excludeTools
            )
        }

        let normalizedToolsFileName = normalizedToolsFileName(toolsFileName)
        let defaultToolsDirectoryURL = defaults.defaultToolsConfigURL.deletingLastPathComponent()
        let localToolsDirectoryURL = defaults.localToolsConfigURL.deletingLastPathComponent()

        return SubAgentToolSettings(
            defaultToolsConfigURL: defaultToolsDirectoryURL
                .appendingPathComponent(normalizedToolsFileName)
                .standardizedFileURL,
            localToolsConfigURL: localToolsDirectoryURL
                .appendingPathComponent(normalizedToolsFileName)
                .standardizedFileURL,
            includeTools: includeTools,
            excludeTools: excludeTools
        )
    }

    private func agentLogsDirectoryURL(
        configurationFileURL: URL,
        agentName: String
    ) -> URL {
        let sanitizedAgentName = sanitizedAgentDirectoryName(agentName)
        return configurationFileURL.standardizedFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("agents", isDirectory: true)
            .appendingPathComponent("logs", isDirectory: true)
            .appendingPathComponent(sanitizedAgentName, isDirectory: true)
    }

    private func sanitizedAgentDirectoryName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let invalidCharacters = CharacterSet(charactersIn: "/\\")
        let components = trimmed.components(separatedBy: invalidCharacters)
        let joined = components.filter { !$0.isEmpty }.joined(separator: "-")
        return joined.isEmpty ? "agent" : joined
    }

    private func normalizedToolsFileName(_ toolsFileName: String) -> String {
        if toolsFileName.hasSuffix(".json") {
            return toolsFileName
        }
        return "\(toolsFileName).json"
    }

    private func makeTool(
        agentConfiguration: SubAgentConfiguration,
        configurationFileURL: URL,
        toolDefaults: SubAgentToolSettings,
        sessionState: SubAgentSessionState,
        modelOverride: String?,
        apiOverride: Config.API?,
        toolOutput: @Sendable @escaping (String) -> Void
    ) -> any ExecutableTool {
        let agentName = agentConfiguration.definition.name
        let toolName = toolName(for: agentName)
        let description = agentConfiguration.definition.description
        let toolSettings = resolveToolSettings(
            defaults: toolDefaults,
            overrides: agentConfiguration.definition.tools
        )
        let logsDirectoryURL = agentLogsDirectoryURL(
            configurationFileURL: configurationFileURL,
            agentName: agentName
        )
        let runner = SubAgentRunner(
            configuration: agentConfiguration,
            toolSettings: toolSettings,
            logDirectoryURL: logsDirectoryURL,
            toolOutput: toolOutput,
            fileManager: fileManager,
            sessionState: sessionState,
            modelOverride: modelOverride,
            apiOverride: apiOverride
        )
        return SubAgentTool(
            name: toolName,
            description: description,
            executeHandler: { request in
                try await runner.run(request: request)
            }
        )
    }
}
