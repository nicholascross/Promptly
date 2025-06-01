import Foundation

struct ChatRequest: Encodable {
    let model: String?
    let messages: [ChatMessage]
    let stream: Bool
    let tools: [ToolSpec]?
    let toolChoice: ToolChoice?

    enum CodingKeys: String, CodingKey {
        case model, messages, stream, tools
        case toolChoice = "tool_choice"
    }
}
