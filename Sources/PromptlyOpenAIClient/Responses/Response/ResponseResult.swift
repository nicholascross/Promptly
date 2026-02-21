import Foundation

public struct ResponseResult: Sendable {
    public let response: APIResponse
    public let streamedOutputs: [Int: String]

    public init(response: APIResponse, streamedOutputs: [Int: String] = [:]) {
        self.response = response
        self.streamedOutputs = streamedOutputs
    }
}
