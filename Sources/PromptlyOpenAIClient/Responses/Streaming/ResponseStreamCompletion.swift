import Foundation

public struct ResponseStreamCompletion: Sendable {
    public let response: APIResponse?
    public let streamedOutputs: [Int: String]
    public let responseId: String?

    public init(response: APIResponse?, streamedOutputs: [Int: String], responseId: String?) {
        self.response = response
        self.streamedOutputs = streamedOutputs
        self.responseId = responseId
    }
}
