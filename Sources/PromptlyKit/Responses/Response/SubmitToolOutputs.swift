import Foundation

struct SubmitToolOutputs: Decodable {
    let toolCalls: [ToolCall]
}
