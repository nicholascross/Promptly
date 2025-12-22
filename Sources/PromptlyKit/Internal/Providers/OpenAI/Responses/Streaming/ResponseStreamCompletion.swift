import Foundation

struct ResponseStreamCompletion {
    let response: APIResponse?
    let streamedOutputs: [Int: String]
    let responseId: String?
}
