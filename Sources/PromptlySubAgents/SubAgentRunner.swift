import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils

struct SubAgentToolDefaults: Sendable {
    let toolsFileName: String
    let includeTools: [String]
    let excludeTools: [String]
}

struct SubAgentRunner: Sendable {
    private struct ToolSettings: Sendable {
        let toolsFileName: String
        let includeTools: [String]
        let excludeTools: [String]
    }

    private static let baseSystemPrompt = """
You are a Promptly sub agent running in an isolated session.
Follow the system guidance and the user request.
Use the available tools when they help you.
When you finish, call \(ReturnToSupervisorTool.toolName) exactly once with the required payload and stop.
You may send status updates with \(ReportProgressToSupervisorTool.toolName).
"""

    private let configuration: SubAgentConfiguration
    private let toolDefaults: SubAgentToolDefaults
    private let toolOutput: @Sendable (String) -> Void

    init(
        configuration: SubAgentConfiguration,
        toolDefaults: SubAgentToolDefaults,
        toolOutput: @Sendable @escaping (String) -> Void
    ) {
        self.configuration = configuration
        self.toolDefaults = toolDefaults
        self.toolOutput = toolOutput
    }

    func run(request: SubAgentToolRequest) async throws -> JSONValue {
        let messages = buildMessages(for: request)
        let tools = try makeTools()

        let coordinator = try PrompterCoordinator(
            config: configuration.configuration,
            tools: tools
        )

        let result = try await coordinator.run(
            messages: messages,
            onEvent: { _ in }
        )

        guard let payload = firstReturnPayload(from: result.promptTranscript) else {
            throw SubAgentToolError.missingReturnPayload(agentName: configuration.definition.name)
        }

        return payload
    }

    private func buildMessages(for request: SubAgentToolRequest) -> [PromptMessage] {
        let systemPrompt = [
            Self.baseSystemPrompt,
            configuration.definition.systemPrompt
        ].joined(separator: "\n\n")

        let systemMessage = PromptMessage(
            role: .system,
            content: .text(systemPrompt)
        )

        let userMessage = PromptMessage(
            role: .user,
            content: .text(buildUserMessageBody(for: request))
        )

        return [systemMessage, userMessage]
    }

    private func buildUserMessageBody(for request: SubAgentToolRequest) -> String {
        var sections: [String] = []
        sections.append("Task:\n\(request.task)")

        if let goals = request.goals, !goals.isEmpty {
            sections.append("Goals:\n\(formatList(goals))")
        }

        if let constraints = request.constraints, !constraints.isEmpty {
            sections.append("Constraints:\n\(formatList(constraints))")
        }

        if let contextPack = request.contextPack {
            sections.append("Context Pack:\n\(formatContextPack(contextPack))")
        }

        return sections.joined(separator: "\n\n")
    }

    private func formatList(_ items: [String]) -> String {
        items.map { "- \($0)" }.joined(separator: "\n")
    }

    private func formatContextPack(_ contextPack: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(contextPack),
           let text = String(data: data, encoding: .utf8) {
            return text
        }
        return contextPack.description
    }

    private func makeTools() throws -> [any ExecutableTool] {
        let settings = resolvedToolSettings()
        let toolFactory = ToolFactory(toolsFileName: settings.toolsFileName)
        let baseTools = try toolFactory.makeTools(
            config: configuration.configuration,
            includeTools: settings.includeTools,
            excludeTools: settings.excludeTools,
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
                toolOutput: toolOutput
            )
        )

        return tools
    }

    private func resolvedToolSettings() -> ToolSettings {
        let overrides = configuration.definition.tools
        return ToolSettings(
            toolsFileName: overrides?.toolsFileName ?? toolDefaults.toolsFileName,
            includeTools: overrides?.include ?? toolDefaults.includeTools,
            excludeTools: overrides?.exclude ?? toolDefaults.excludeTools
        )
    }

    private func isDisallowedToolName(_ name: String) -> Bool {
        if name.hasPrefix("SubAgent.") {
            return true
        }
        let reservedNames = [
            ReturnToSupervisorTool.toolName,
            ReportProgressToSupervisorTool.toolName
        ]
        return reservedNames.contains(name)
    }

    private func firstReturnPayload(from transcript: [PromptTranscriptEntry]) -> JSONValue? {
        for entry in transcript {
            guard case let .toolCall(_, name, arguments, output) = entry else { continue }
            guard name == ReturnToSupervisorTool.toolName else { continue }
            return output ?? arguments
        }
        return nil
    }
}
