import Foundation
import PromptlyOpenAIClient
import PromptlyKitUtils

extension PromptMessage {
    func asChatMessage(encoder: JSONEncoder = JSONEncoder()) throws -> ChatMessage {
        let role: ChatRole
        switch self.role {
        case .system:
            role = .system
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        case .tool:
            role = .tool
        }

        let content: Content
        switch self.content {
        case let .text(text):
            content = .text(text)
        case let .json(value):
            content = .text(try encodeJSONValue(value, encoder: encoder))
        case .empty:
            content = .empty
        }

        let toolCalls = try toolCalls?.map { call in
            guard let id = call.id else {
                throw PromptError.apiError("Tool call identifier is missing.")
            }
            return ChatFunctionCall(
                id: id,
                function: try ChatFunction(name: call.name, arguments: call.arguments),
                type: "function"
            )
        }

        if role == .tool, toolCallId == nil {
            throw PromptError.apiError("Tool call identifier is missing for tool output.")
        }

        return ChatMessage(
            role: role,
            content: content,
            toolCalls: toolCalls,
            toolCallId: toolCallId
        )
    }

    private func encodeJSONValue(_ value: JSONValue, encoder: JSONEncoder) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PromptError.apiError("Failed to encode tool output.")
        }
        return text
    }
}

extension Array where Element == PromptMessage {
    func asChatMessages(encoder: JSONEncoder = JSONEncoder()) throws -> [ChatMessage] {
        try map { message in
            try message.asChatMessage(encoder: encoder)
        }
    }
}
