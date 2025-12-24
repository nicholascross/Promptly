import PromptlyKit
import PromptlyKitUtils

struct ReturnToSupervisorTool: ExecutableTool, Sendable {
    let name = "ReturnToSupervisor"
    let description = "Return the final sub agent payload to the supervisor."
    let parameters: JSONSchema = ReturnToSupervisorTool.parameterSchema

    func execute(arguments: JSONValue) async throws -> JSONValue {
        arguments
    }
}

private extension ReturnToSupervisorTool {
    static let parameterSchema: JSONSchema = {
        let artifactSchema = JSONSchema.object(
            requiredProperties: [
                "type": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "One of file, command, note, or data."
                ),
                "description": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Short artifact description."
                )
            ],
            optionalProperties: [
                "path": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "File path when type is file."
                ),
                "command": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Suggested command when type is command."
                ),
                "content": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Inline content when type is note or data."
                )
            ],
            description: "Artifact reference returned by a sub agent."
        )

        return .object(
            requiredProperties: [
                "result": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Primary result of the sub agent work."
                ),
                "summary": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Compact summary for the supervisor."
                )
            ],
            optionalProperties: [
                "artifacts": .array(
                    items: artifactSchema,
                    description: "Structured artifacts to share."
                ),
                "evidence": .array(
                    items: .string(
                        minLength: 1,
                        maxLength: nil,
                        pattern: nil,
                        format: nil,
                        description: "Evidence entry."
                    ),
                    description: "Brief excerpts or notes that justify the result."
                ),
                "confidence": .number(
                    minimum: 0,
                    maximum: 1,
                    description: "Confidence level between 0 and 1."
                ),
                "needsSupervisorDecision": .boolean(
                    description: "Whether the supervisor needs to decide next steps."
                ),
                "decisionReason": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Reason when a supervisor decision is needed."
                ),
                "logPath": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Transcript log path."
                )
            ],
            description: "Return payload for a sub agent session."
        )
    }()
}
