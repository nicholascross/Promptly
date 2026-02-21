import Foundation

public struct FunctionCallOutputItem: Encodable, Sendable {
    public let callId: String
    public let output: String

    public init(callId: String, output: String) {
        self.callId = callId
        self.output = output
    }

    enum CodingKeys: String, CodingKey {
        case type
        case callId = "call_id"
        case output
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("function_call_output", forKey: .type)
        try container.encode(callId, forKey: .callId)
        try container.encode(output, forKey: .output)
    }
}
