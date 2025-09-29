import Foundation

struct APIResponse: Decodable {
    enum Status: String, Decodable {
        case inProgress = "in_progress"
        case requiresAction = "requires_action"
        case completed
        case failed
        case cancelled
    }

    let id: String
    let status: Status
    let output: [ResponseOutput]?
    let requiredAction: RequiredAction?
    let error: APIErrorEnvelope.APIError?

    func combinedOutputText() -> String? {
        guard let output else { return nil }
        let texts = output.flatMap { $0.outputTextFragments() }
        return texts.joined()
    }

    func toolCalls() -> [ToolCall] {
        var calls = output?.compactMap { $0.asToolCall() } ?? []
        if let actionCalls = requiredAction?.submitToolOutputs?.toolCalls {
            calls.append(contentsOf: actionCalls)
        }
        return calls
    }

    var errorMessage: String? { error?.message }
}
