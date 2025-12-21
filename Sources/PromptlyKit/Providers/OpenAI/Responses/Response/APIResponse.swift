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
    let outputText: String?
    let requiredAction: RequiredAction?
    let error: APIErrorEnvelope.APIError?

    enum CodingKeys: String, CodingKey {
        case id
        case status
        case output
        case outputText = "output_text"
        case requiredAction = "required_action"
        case error
    }

    func combinedOutputText() -> String? {
        if let output, !output.isEmpty {
            let texts = output.flatMap { $0.outputTextFragments() }
            if !texts.isEmpty {
                return texts.joined()
            }
        }
        return outputText
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
