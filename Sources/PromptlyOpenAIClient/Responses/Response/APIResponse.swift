import Foundation

public struct APIResponse: Decodable, Sendable {
    public enum Status: String, Decodable, Sendable {
        case inProgress = "in_progress"
        case requiresAction = "requires_action"
        case completed
        case failed
        case cancelled
    }

    public let id: String
    public let status: Status
    public let output: [ResponseOutput]?
    public let outputText: String?
    public let requiredAction: RequiredAction?
    public let error: APIErrorEnvelope.APIError?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case output
        case outputText = "output_text"
        case requiredAction = "required_action"
        case error
    }

    public func combinedOutputText() -> String? {
        if let output, !output.isEmpty {
            let texts = output.flatMap { $0.outputTextFragments() }
            if !texts.isEmpty {
                return texts.joined()
            }
        }
        return outputText
    }

    public func toolCalls() -> [ToolCall] {
        var calls = output?.compactMap { $0.asToolCall() } ?? []
        if let actionCalls = requiredAction?.submitToolOutputs?.toolCalls {
            calls.append(contentsOf: actionCalls)
        }
        return calls
    }

    public var errorMessage: String? { error?.message }
}
