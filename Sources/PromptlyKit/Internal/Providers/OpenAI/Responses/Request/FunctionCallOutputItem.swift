import Foundation

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
