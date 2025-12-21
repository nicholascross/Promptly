import Foundation
import PromptlyKitUtils

struct ResponseStreamPayload: Decodable {
    let type: String
    let delta: JSONValue?
    let response: APIResponse?
    let error: APIErrorEnvelope.APIError?
    let outputIndex: Int?
    let responseId: String?

    enum CodingKeys: String, CodingKey {
        case type
        case delta
        case response
        case error
        case outputIndex = "output_index"
        case responseId = "response_id"
    }
}
