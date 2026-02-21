import Foundation

public struct RequiredAction: Decodable, Sendable {
    public let type: String?
    public let submitToolOutputs: SubmitToolOutputs?

    enum CodingKeys: String, CodingKey {
        case type
        case submitToolOutputs = "submit_tool_outputs"
    }
}
