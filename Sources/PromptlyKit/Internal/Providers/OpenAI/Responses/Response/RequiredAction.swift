import Foundation

struct RequiredAction: Decodable {
    let type: String?
    let submitToolOutputs: SubmitToolOutputs?

    enum CodingKeys: String, CodingKey {
        case type
        case submitToolOutputs = "submit_tool_outputs"
    }
}
