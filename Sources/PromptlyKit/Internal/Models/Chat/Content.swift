import Foundation

enum Content: Codable, Sendable {
    case text(String)
    case blocks([ContentBlock])
    case empty

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case let .text(str):
            try container.encode(str)
        case let .blocks(blocks):
            try container.encode(blocks)
        case .empty:
            try container.encode([ContentBlock]())
        }
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            if blocks.isEmpty {
                self = .empty
            } else {
                self = .blocks(blocks)
            }
        } else {
            self = .empty
        }
    }
}

extension Content {
    func blocks(for role: ChatRole) -> [ContentBlock] {
        switch self {
        case let .text(text):
            switch role {
            case .system, .user:
                return [ContentBlock(type: "input_text", text: text)]
            case .assistant:
                return [ContentBlock(type: "output_text", text: text)]
            case .tool:
                return [ContentBlock(type: "input_text", text: text)]
            }
        case let .blocks(blocks):
            return blocks
        case .empty:
            return []
        }
    }
}
