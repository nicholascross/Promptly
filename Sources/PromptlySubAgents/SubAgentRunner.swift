import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils

struct SubAgentToolSettings: Sendable {
    let defaultToolsConfigURL: URL
    let localToolsConfigURL: URL
    let includeTools: [String]
    let excludeTools: [String]
}

struct SubAgentRunner: Sendable {
    private static let baseSystemPrompt = """
You are a Promptly sub agent running in an isolated session.
Follow the system guidance and the user request.
Use the available tools when they help you.
When you finish, call \(ReturnToSupervisorTool.toolName) exactly once with the required payload and stop.
You may send status updates with \(ReportProgressToSupervisorTool.toolName).
"""

    private let configuration: SubAgentConfiguration
    private let toolSettings: SubAgentToolSettings
    private let logDirectoryURL: URL
    private let toolOutput: @Sendable (String) -> Void

    init(
        configuration: SubAgentConfiguration,
        toolSettings: SubAgentToolSettings,
        logDirectoryURL: URL,
        toolOutput: @Sendable @escaping (String) -> Void
    ) {
        self.configuration = configuration
        self.toolSettings = toolSettings
        self.logDirectoryURL = logDirectoryURL.standardizedFileURL
        self.toolOutput = toolOutput
    }

    func run(request: SubAgentToolRequest) async throws -> JSONValue {
        let transcriptLogger = try? SubAgentTranscriptLogger(
            logsDirectoryURL: logDirectoryURL
        )
        var didFinishLogging = false

        let messages = buildMessages(for: request)
        let tools = try makeTools(transcriptLogger: transcriptLogger)

        let coordinator = try PrompterCoordinator(
            config: configuration.configuration,
            tools: tools
        )

        do {
            let result = try await coordinator.run(
                messages: messages,
                onEvent: { event in
                    await transcriptLogger?.handle(event: event)
                }
            )

            guard let payload = firstReturnPayload(from: result.promptTranscript) else {
                await transcriptLogger?.finish(status: "missing_return_payload", error: nil)
                didFinishLogging = true
                throw SubAgentToolError.missingReturnPayload(agentName: configuration.definition.name)
            }

            let payloadWithLogPath = attachLogPath(
                to: payload,
                logPath: transcriptLogger?.logPath
            )
            await transcriptLogger?.recordReturnPayload(payloadWithLogPath)
            await transcriptLogger?.finish(status: "completed", error: nil)
            didFinishLogging = true

            return payloadWithLogPath
        } catch {
            if !didFinishLogging {
                await transcriptLogger?.finish(status: "failed", error: error)
            }
            throw error
        }
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

    private func makeTools(
        transcriptLogger: SubAgentTranscriptLogger?
    ) throws -> [any ExecutableTool] {
        let toolFactory = ToolFactory(
            defaultToolsConfigURL: toolSettings.defaultToolsConfigURL,
            localToolsConfigURL: toolSettings.localToolsConfigURL
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

    private func attachLogPath(to payload: JSONValue, logPath: String?) -> JSONValue {
        guard let logPath else {
            return payload
        }
        guard case let .object(object) = payload else {
            return payload
        }
        var updated = object
        updated["logPath"] = .string(logPath)
        return .object(updated)
    }
}
