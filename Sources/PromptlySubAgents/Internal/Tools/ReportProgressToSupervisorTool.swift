import PromptlyKit
import PromptlyKitUtils

struct ReportProgressToSupervisorTool: ExecutableTool, Sendable {
    static let toolName = "ReportProgressToSupervisor"

    let name = ReportProgressToSupervisorTool.toolName
    let description = "Report a progress update for the supervisor without ending the session."
    let parameters: JSONSchema = ReportProgressToSupervisorTool.parameterSchema

    private let agentName: String
    private let toolOutput: @Sendable (String) -> Void
    init(
        agentName: String,
        toolOutput: @Sendable @escaping (String) -> Void
    ) {
        self.agentName = agentName.trimmingCharacters(in: .whitespacesAndNewlines)
        self.toolOutput = toolOutput
    }

    func execute(arguments: JSONValue) async throws -> JSONValue {
        let request = try arguments.decoded(ReportProgressToSupervisorRequest.self)
        toolOutput(formatProgressOutput(from: request))
        return arguments
    }

    private func formatProgressOutput(from request: ReportProgressToSupervisorRequest) -> String {
        var details: [String] = []

        if let status = request.status {
            details.append(status)
        }
        if let summary = request.summary {
            details.append(summary)
        }
        if let currentStep = request.currentStep {
            details.append("Current step: \(currentStep)")
        }
        if let percentComplete = request.percentComplete {
            details.append("Percent complete: \(percentComplete)")
        }
        if let blockers = request.blockers, !blockers.isEmpty {
            details.append("Blockers: \(blockers.joined(separator: ", "))")
        }

        let body = details.isEmpty ? "Progress update" : details.joined(separator: " | ")
        return "[sub-agent:\(agentName)] \(body)\n"
    }
}

private extension ReportProgressToSupervisorTool {
    static let parameterSchema: JSONSchema = {
        .object(
            requiredProperties: [:],
            optionalProperties: [
                "status": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Short status line."
                ),
                "summary": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "One or two sentence progress summary."
                ),
                "currentStep": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Optional phase or step name."
                ),
                "percentComplete": .number(
                    minimum: 0,
                    maximum: 1,
                    description: "Progress indicator between 0 and 1."
                ),
                "blockers": .array(
                    items: .string(
                        minLength: 1,
                        maxLength: nil,
                        pattern: nil,
                        format: nil,
                        description: "Blocker entry."
                    ),
                    description: "Blockers or decisions needed."
                )
            ],
            description: "Progress update payload."
        )
    }()
}
