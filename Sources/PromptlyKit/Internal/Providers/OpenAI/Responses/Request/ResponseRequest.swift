import Foundation

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
