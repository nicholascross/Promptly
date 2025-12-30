import PromptlyKit
import PromptlyKitUtils

struct SubAgentTool: ExecutableTool, Sendable {
    let name: String
    let description: String
    let parameters: JSONSchema
    private let executeHandler: @Sendable (SubAgentToolRequest) async throws -> JSONValue

    init(
        name: String,
        description: String,
        executeHandler: @Sendable @escaping (SubAgentToolRequest) async throws -> JSONValue
    ) {
        self.name = name
        self.description = description
        parameters = Self.parameterSchema
        self.executeHandler = executeHandler
    }

    func execute(arguments: JSONValue) async throws -> JSONValue {
        let request = try arguments.decoded(SubAgentToolRequest.self)
        return try await executeHandler(request)
    }
}

private extension SubAgentTool {
    static let parameterSchema: JSONSchema = {
        let snippetSchema = JSONSchema.object(
            requiredProperties: [
                "path": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Path for the snippet."
                ),
                "content": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Snippet content."
                )
            ],
            optionalProperties: [
                "startLine": .integer(
                    minimum: 1,
                    maximum: nil,
                    description: "Starting line for the snippet."
                ),
                "endLine": .integer(
                    minimum: 1,
                    maximum: nil,
                    description: "Ending line for the snippet."
                )
            ],
            description: "File snippet metadata."
        )

        let contextPackSchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [
                "summary": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Short context summary."
                ),
                "snippets": .array(
                    items: snippetSchema,
                    description: "File snippets for context."
                ),
                "notes": .array(
                    items: .string(
                        minLength: 1,
                        maxLength: nil,
                        pattern: nil,
                        format: nil,
                        description: "Additional notes."
                    ),
                    description: "Additional context notes."
                )
            ],
            description: "Structured context pack for the sub agent."
        )

        return .object(
            requiredProperties: [
                "task": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Task statement for the sub agent."
                )
            ],
            optionalProperties: [
                "contextPack": contextPackSchema,
                "goals": .array(
                    items: .string(
                        minLength: 1,
                        maxLength: nil,
                        pattern: nil,
                        format: nil,
                        description: "Goal statement."
                    ),
                    description: "Ordered objectives."
                ),
                "constraints": .array(
                    items: .string(
                        minLength: 1,
                        maxLength: nil,
                        pattern: nil,
                        format: nil,
                        description: "Constraint statement."
                    ),
                    description: "Ordered constraints."
                ),
                "resumeId": .string(
                    minLength: 1,
                    maxLength: nil,
                    pattern: nil,
                    format: nil,
                    description: "Resume identifier from a prior sub agent run."
                )
            ],
            description: "Parameters for invoking a sub agent."
        )
    }()
}
