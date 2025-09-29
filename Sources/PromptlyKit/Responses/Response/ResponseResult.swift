import Foundation

struct ResponseResult {
    let response: APIResponse
    let streamedOutputs: [Int: String]

    init(response: APIResponse, streamedOutputs: [Int: String] = [:]) {
        self.response = response
        self.streamedOutputs = streamedOutputs
    }

    var didStream: Bool {
        streamedOutputs.values.contains { !$0.isEmpty }
    }
}
