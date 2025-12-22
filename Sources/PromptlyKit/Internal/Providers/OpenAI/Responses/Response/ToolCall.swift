import Foundation

struct ToolCall: Decodable {
    struct FunctionCall: Decodable {
        let name: String
        let arguments: String
    }

    let id: String
    let callId: String
    let type: String
    let function: FunctionCall

    enum CodingKeys: String, CodingKey {
        case id
        case type
        case function
        case callId = "call_id"
    }

    init(id: String, callId: String, type: String, function: FunctionCall) {
        self.id = id
        self.callId = callId
        self.type = type
        self.function = function
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        type = try container.decode(String.self, forKey: .type)
        function = try container.decode(FunctionCall.self, forKey: .function)

        let decodedCallId = try container.decodeIfPresent(String.self, forKey: .callId)
        let decodedId = try container.decodeIfPresent(String.self, forKey: .id)

        switch (decodedId, decodedCallId) {
        case let (id?, callId?):
            self.id = id
            self.callId = callId
        case let (id?, nil):
            self.id = id
            self.callId = id
        case let (nil, callId?):
            self.id = callId
            self.callId = callId
        case (nil, nil):
            throw DecodingError.dataCorruptedError(
                forKey: .id,
                in: container,
                debugDescription: "ToolCall is missing an identifier."
            )
        }
    }
}
