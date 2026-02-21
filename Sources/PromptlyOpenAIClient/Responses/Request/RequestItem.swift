import Foundation

public enum RequestItem: Encodable, Sendable {
    case message(ChatMessage)
    case functionOutput(FunctionCallOutputItem)

    public func encode(to encoder: Encoder) throws {
        switch self {
        case let .message(message):
            try message.encode(to: encoder)
        case let .functionOutput(output):
            try output.encode(to: encoder)
        }
    }
}
