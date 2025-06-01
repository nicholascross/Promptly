import Foundation

struct Delta: Decodable {
    let content: String?
    let toolCalls: [RawToolCall]?
    enum CodingKeys: String, CodingKey {
        case content, toolCalls = "tool_calls"
    }
}

struct RawToolCall: Decodable {
    let id: String? // only present on first chunk
    let function: FunctionDescriptor
    struct FunctionDescriptor: Decodable {
        let name: String? // only present on first chunk
        let arguments: String // every chunk has this
    }
}
