import Foundation

enum RequestItem: Encodable, Sendable {
    case message(ChatMessage)
    case functionOutput(FunctionCallOutputItem)

    func encode(to encoder: Encoder) throws {
        switch self {
        case let .message(message):
            try message.encode(to: encoder)
        case let .functionOutput(output):
            try output.encode(to: encoder)
        }
    }
}
