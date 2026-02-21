import Foundation

public struct SubmitToolOutputs: Decodable, Sendable {
    public let toolCalls: [ToolCall]

    enum CodingKeys: String, CodingKey {
        case toolCalls = "tool_calls"
    }
}
