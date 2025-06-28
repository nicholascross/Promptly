import Foundation

struct Choice: Decodable {
    let delta: Delta
    let finishReason: String?
    enum CodingKeys: String, CodingKey {
        case delta, finishReason = "finish_reason"
    }
}
