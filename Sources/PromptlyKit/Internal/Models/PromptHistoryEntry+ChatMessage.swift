import Foundation
import PromptlyKitUtils

extension PromptHistoryEntry {
    func asChatMessage(encoder: JSONEncoder) throws -> ChatMessage {
        switch self {
        case let .message(promptMessage):
            return promptMessage.asChatMessage()
        case let .toolCall(id, name, arguments):
            guard let id else {
                throw PromptError.apiError("Tool call identifier is missing.")
            }
            let function = try ChatFunction(name: name, arguments: arguments)
            return ChatMessage(
                role: .assistant,
                id: id,
                content: .empty,
                toolCalls: [
                    ChatFunctionCall(
                        id: id,
                        function: function,
                        type: "function"
                    )
                ]
            )
        case let .toolOutput(toolCallId, output):
            guard let toolCallId else {
                throw PromptError.apiError("Tool call identifier is missing for tool output.")
            }
            let encodedOutput = try encodeJSONValue(output, encoder: encoder)
            return ChatMessage(
                role: .tool,
                content: .text(encodedOutput),
                toolCallId: toolCallId
            )
        }
    }

    private func encodeJSONValue(_ value: JSONValue, encoder: JSONEncoder) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PromptError.apiError("Failed to encode tool output.")
        }
        return text
    }
}

extension Array where Element == PromptHistoryEntry {
    func asChatMessages(encoder: JSONEncoder = JSONEncoder()) throws -> [ChatMessage] {
        try map { entry in
            try entry.asChatMessage(encoder: encoder)
        }
    }
}
