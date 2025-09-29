import Foundation

enum RequestItem: Encodable, Sendable {
    case message(ChatMessage)
    case functionOutput(FunctionCallOutputItem)

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .message(message):
            try message.encode(to: encoder)
        case let .functionOutput(output):
            try output.encode(to: encoder)
        }
    }
}

struct FunctionCallOutputItem: Encodable, Sendable {
    let callId: String
    let output: String

    enum CodingKeys: String, CodingKey {
        case type
        case callId = "call_id"
        case output
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("function_call_output", forKey: .type)
        try container.encode(callId, forKey: .callId)
        try container.encode(output, forKey: .output)
    }
}

struct ResponseRequest: Encodable {
    let model: String?
    let input: [RequestItem]
    let stream: Bool
    let tools: [ToolSpec]?
    let toolChoice: ToolChoice?
    let previousResponseId: String?

    enum CodingKeys: String, CodingKey {
        case model, input, stream, tools
        case toolChoice = "tool_choice"
        case previousResponseId = "previous_response_id"
    }
}
