import Foundation

struct RequiredAction: Decodable {
    let type: String?
    let submitToolOutputs: SubmitToolOutputs?
}
