import Foundation

struct SubmitToolOutputs: Decodable {
    let toolCalls: [ToolCall]

    enum CodingKeys: String, CodingKey {
        case toolCalls = "tool_calls"
    }
}
