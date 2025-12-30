import Foundation

public extension Config {
    enum API: Decodable, Sendable {
        case responses
        case chatCompletions

        public init(from decoder: Decoder) throws {
            let container = try decoder.singleValueContainer()
            let raw = try container.decode(String.self).lowercased()
            switch raw {
            case "responses", "response":
                self = .responses
            case "chat", "chat_completions", "chat-completions", "chatcompletions", "completions":
                self = .chatCompletions
            default:
                throw DecodingError.dataCorruptedError(
                    in: container,
                    debugDescription: "Unknown API value '\(raw)'"
                )
            }
        }
    }
}
