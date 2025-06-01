import Foundation

public enum Content: Codable {
    case text(String)
    case blocks([ContentBlock])
    case empty

    public func encode(to encoder: Encoder) throws {
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

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let str = try? container.decode(String.self) {
            self = .text(str)
        } else if let blocks = try? container.decode([ContentBlock].self) {
            self = .blocks(blocks)
        } else {
            self = .empty
        }
    }
}
