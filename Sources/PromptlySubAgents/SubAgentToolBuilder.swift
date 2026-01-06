import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils

struct SubAgentToolBuilder: Sendable {
    private let configuration: SubAgentConfiguration
    private let toolSettings: SubAgentToolSettings
    private let fileManager: FileManagerProtocol
    private let toolOutput: @Sendable (String) -> Void

    init(
        configuration: SubAgentConfiguration,
        toolSettings: SubAgentToolSettings,
        fileManager: FileManagerProtocol,
        toolOutput: @Sendable @escaping (String) -> Void
    ) {
        self.configuration = configuration
        self.toolSettings = toolSettings
        self.fileManager = fileManager
        self.toolOutput = toolOutput
    }

    func makeTools(
        transcriptLogger: SubAgentTranscriptLogger?
    ) throws -> [any ExecutableTool] {
        let toolFactory = ToolFactory(
            fileManager: fileManager,
            toolsFileName: toolSettings.toolsFileName
        )
        let baseTools = try toolFactory.makeTools(
            config: configuration.configuration,
            includeTools: toolSettings.includeTools,
            excludeTools: toolSettings.excludeTools,
            toolOutput: toolOutput
        )

        let filteredTools = baseTools.filter { tool in
            !isDisallowedToolName(tool.name)
        }

        var tools = filteredTools
        tools.append(
            ReturnToSupervisorTool()
        )
        tools.append(
            ReportProgressToSupervisorTool(
                agentName: configuration.definition.name,
                toolOutput: toolOutput,
                transcriptLogger: transcriptLogger
            )
        )

        return tools
    }

    private func isDisallowedToolName(_ name: String) -> Bool {
        if name.hasPrefix("SubAgent-") {
            return true
        }
        let reservedNames = [
            ReturnToSupervisorTool.toolName,
            ReportProgressToSupervisorTool.toolName
        ]
        return reservedNames.contains(name)
    }
}
