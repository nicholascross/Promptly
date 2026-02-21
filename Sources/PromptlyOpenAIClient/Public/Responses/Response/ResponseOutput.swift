import Foundation

public struct ResponseOutput: Decodable, Sendable {
    public let id: String?
    public let callId: String?
    public let type: String
    public let status: String?
    public let content: [OutputContent]?
    public let text: String?
    public let role: String?
    public let name: String?
    public let arguments: String?

    enum CodingKeys: String, CodingKey {
        case id
        case callId = "call_id"
        case type
        case status
        case content
        case text
        case role
        case name
        case arguments
    }

    public func outputTextFragments() -> [String] {
        if type == "output_text" {
            if let text, !text.isEmpty {
                return [text]
            }
            guard let content else { return [] }
            return content.compactMap { $0.text }
        }

        if type == "message" {
            guard let content else { return [] }
            return content.filter { $0.type == "output_text" }.compactMap { $0.text }
        }

        return []
    }

    public func asToolCall() -> ToolCall? {
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
