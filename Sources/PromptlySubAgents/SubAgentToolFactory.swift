import Foundation
import PromptlyAssets
import PromptlyDetachedTask
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
        toolsFileName: String,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> [any ExecutableTool] {
        let normalizedFileName = normalizedToolsFileName(toolsFileName)
        let toolDefaults = SubAgentToolSettings(
            toolsFileName: normalizedFileName,
            includeTools: includeTools,
            excludeTools: excludeTools
        )
        let resumeStore = DetachedTaskResumeStore()

        let agentConfigurations = try loadAgentConfigurations(
            configurationFileURL: configurationFileURL
        )

        var tools: [any ExecutableTool] = []
        tools.reserveCapacity(agentConfigurations.count)

        for agentConfiguration in agentConfigurations {
            let tool = makeTool(
                agentConfiguration: agentConfiguration,
                configurationFileURL: configurationFileURL,
                toolDefaults: toolDefaults,
                resumeStore: resumeStore,
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
        let agentConfigurations = try loadAgentConfigurations(
            configurationFileURL: configurationFileURL
        )

        var hintLines: [String] = []
        hintLines.reserveCapacity(agentConfigurations.count)

        for agentConfiguration in agentConfigurations {
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
        let preferenceGuidance = "Prefer a matching sub agent over a shell tool when both can handle the request."
        let resumeGuidance = """
When a sub agent returns needsMoreInformation or needsSupervisorDecision, gather the requested input or decision from the user.
Then call the same sub agent tool again with the resumeId, and include the user's answers in the task or context pack notes.
"""
        return ([header, preferenceGuidance] + hintLines + ["", resumeGuidance]).joined(separator: "\n")
    }

    public func makeTool(
        configurationFileURL: URL,
        agentConfigurationURL: URL,
        toolsFileName: String,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> any ExecutableTool {
        let normalizedFileName = normalizedToolsFileName(toolsFileName)
        let toolDefaults = SubAgentToolSettings(
            toolsFileName: normalizedFileName,
            includeTools: includeTools,
            excludeTools: excludeTools
        )
        let resumeStore = DetachedTaskResumeStore()
        let agentConfiguration = try configurationLoader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentConfigurationURL
        )
        return makeTool(
            agentConfiguration: agentConfiguration,
            configurationFileURL: configurationFileURL,
            toolDefaults: toolDefaults,
            resumeStore: resumeStore,
            modelOverride: modelOverride,
            apiOverride: apiOverride,
            toolOutput: toolOutput
        )
    }

    public func makeTool(
        configurationFileURL: URL,
        agentConfigurationData: Data,
        agentSourceURL: URL,
        toolsFileName: String,
        modelOverride: String? = nil,
        apiOverride: Config.API? = nil,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> any ExecutableTool {
        let normalizedFileName = normalizedToolsFileName(toolsFileName)
        let toolDefaults = SubAgentToolSettings(
            toolsFileName: normalizedFileName,
            includeTools: includeTools,
            excludeTools: excludeTools
        )
        let resumeStore = DetachedTaskResumeStore()
        let agentConfiguration = try configurationLoader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationData: agentConfigurationData,
            sourceURL: agentSourceURL
        )
        return makeTool(
            agentConfiguration: agentConfiguration,
            configurationFileURL: configurationFileURL,
            toolDefaults: toolDefaults,
            resumeStore: resumeStore,
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
                toolsFileName: defaults.toolsFileName,
                includeTools: includeTools,
                excludeTools: excludeTools
            )
        }

        return SubAgentToolSettings(
            toolsFileName: normalizedToolsFileName(toolsFileName),
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
        resumeStore: DetachedTaskResumeStore,
        modelOverride: String?,
        apiOverride: Config.API?,
        toolOutput: @Sendable @escaping (String) -> Void
    ) -> any ExecutableTool {
        makeDetachedTaskTool(
            agentConfiguration: agentConfiguration,
            configurationFileURL: configurationFileURL,
            toolDefaults: toolDefaults,
            resumeStore: resumeStore,
            modelOverride: modelOverride,
            apiOverride: apiOverride,
            toolOutput: toolOutput
        )
    }

    private func makeDetachedTaskTool(
        agentConfiguration: SubAgentConfiguration,
        configurationFileURL: URL,
        toolDefaults: SubAgentToolSettings,
        resumeStore: DetachedTaskResumeStore,
        modelOverride: String?,
        apiOverride: Config.API?,
        toolOutput: @Sendable @escaping (String) -> Void
    ) -> any ExecutableTool {
        let localFileManager = fileManager
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
        let effectiveApi = apiOverride ?? agentConfiguration.configuration.api
        let requestAdapter = SubAgentDetachedTaskRequestAdapter()
        let payloadAdapter = SubAgentDetachedTaskPayloadAdapter()

        return SubAgentTool(
            name: toolName,
            description: description,
            executeHandler: { request in
                let toolBuilder = SubAgentToolBuilder(
                    configuration: agentConfiguration,
                    toolSettings: toolSettings,
                    fileManager: localFileManager,
                    toolOutput: toolOutput
                )
                let tools = try toolBuilder.makeTools()
                let modelRunner = try PromptRunCoordinatorModelRunner(
                    configuration: agentConfiguration.configuration,
                    tools: tools,
                    modelOverride: modelOverride,
                    apiOverride: apiOverride
                )
                let resumeStrategy = DetachedTaskResumeStrategyFactory.make(
                    for: effectiveApi
                )
                let promptAssembler = DetachedTaskPromptAssembler(
                    agentSystemPrompt: agentConfiguration.definition.systemPrompt,
                    returnToolName: ReturnToSupervisorTool.toolName,
                    progressToolName: ReportProgressToSupervisorTool.toolName,
                    resumeStrategy: resumeStrategy
                )
                let returnPayloadResolver = DetachedTaskReturnPayloadResolver(
                    returnToolName: ReturnToSupervisorTool.toolName
                )
                let logSink = try? DetachedTaskTranscriptLogSink(
                    logsDirectoryURL: logsDirectoryURL,
                    fileManager: localFileManager
                )
                let runner = DetachedTaskRunner(
                    agentName: agentName,
                    promptAssembler: promptAssembler,
                    modelRunner: modelRunner,
                    returnPayloadResolver: returnPayloadResolver,
                    resumeStore: resumeStore,
                    logSink: logSink
                )
                let detachedRequest = requestAdapter.detachedTaskRequest(
                    from: request
                )
                let result = try await runner.run(request: detachedRequest)
                return payloadAdapter.jsonValue(from: result.payload)
            }
        )
    }

    private func loadAgentConfigurations(
        configurationFileURL: URL
    ) throws -> [SubAgentConfiguration] {
        let agentURLs = try configurationLoader.discoverAgentConfigurationURLs(
            configFileURL: configurationFileURL
        )
        var configurations: [SubAgentConfiguration] = []
        configurations.reserveCapacity(agentURLs.count)
        var existingNames = Set<String>()

        for agentURL in agentURLs {
            let agentConfiguration = try configurationLoader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationURL: agentURL
            )
            configurations.append(agentConfiguration)
            let identifier = agentURL.deletingPathExtension().lastPathComponent
            existingNames.insert(identifier.lowercased())
        }

        let bundledAgents = BundledAgentDefaults()
        let bundledNames = bundledAgents.agentNames()
        guard !bundledNames.isEmpty else {
            return configurations
        }

        for name in bundledNames where !existingNames.contains(name.lowercased()) {
            guard let data = bundledAgents.agentData(name: name),
                  let sourceURL = bundledAgents.agentURL(name: name) else {
                continue
            }
            let agentConfiguration = try configurationLoader.loadAgentConfiguration(
                configFileURL: configurationFileURL,
                agentConfigurationData: data,
                sourceURL: sourceURL
            )
            configurations.append(agentConfiguration)
        }

        return configurations
    }
}
