import Foundation

struct ResponseOutput: Decodable {
    let id: String?
    let callId: String?
    let type: String
    let status: String?
    let content: [OutputContent]?
    let role: String?
    let name: String?
    let arguments: String?

    enum CodingKeys: String, CodingKey {
        case id
        case callId = "call_id"
        case type
        case status
        case content
        case role
        case name
        case arguments
    }

    func outputTextFragments() -> [String] {
        guard let content else { return [] }

        if type == "output_text" {
            return content.compactMap { $0.text }
        }

        if type == "message" {
            return content.filter { $0.type == "output_text" }.compactMap { $0.text }
        }

        return []
    }

    func asToolCall() -> ToolCall? {
        guard type == "function_call", let name, let arguments else { return nil }
        guard let callIdentifier = callId ?? id else { return nil }
        let toolIdentifier = id ?? callIdentifier
        return ToolCall(
            id: toolIdentifier,
            callId: callIdentifier,
            type: "function",
            function: .init(name: name, arguments: arguments)
        )
    }
}
