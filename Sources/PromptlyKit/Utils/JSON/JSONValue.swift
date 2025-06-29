import Foundation

/// A JSON value (string, number, boolean, object, array, or null).
public enum JSONValue: Codable, Sendable, CustomStringConvertible {
    case string(String)
    case integer(Int)
    case number(Double)
    case bool(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    /// Build a JSONValue from any Encodable value via JSON round-trip.
    public init<T: Encodable>(_ value: T) throws {
        let data = try JSONEncoder().encode(value)
        self = try JSONDecoder().decode(JSONValue.self, from: data)
    }

    /// Decode this JSONValue into any Decodable type via JSON round-trip.
    public func decoded<T: Decodable>(_: T.Type) throws -> T {
        let data = try JSONEncoder().encode(self)
        return try JSONDecoder().decode(T.self, from: data)
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let bool = try? container.decode(Bool.self) {
            self = .bool(bool)
        } else if let integer = try? container.decode(Int.self) {
            self = .integer(integer)
        } else if let double = try? container.decode(Double.self) {
            self = .number(double)
        } else if let number = try? container.decode(String.self) {
            self = .string(number)
        } else if let arr = try? container.decode([JSONValue].self) {
            self = .array(arr)
        } else if let obj = try? container.decode([String: JSONValue].self) {
            self = .object(obj)
        } else {
            throw DecodingError.dataCorruptedError(
                in: container,
                debugDescription: "Cannot decode JSONValue"
            )
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .null:
            try container.encodeNil()
        case let .bool(bool):
            try container.encode(bool)
        case let .integer(integer):
            try container.encode(integer)
        case let .number(number):
            try container.encode(number)
        case let .string(string):
            try container.encode(string)
        case let .array(array):
            try container.encode(array)
        case let .object(object):
            try container.encode(object)
        }
    }

    public var description: String {
        switch self {
        case .string(let value):
            return value
        case .integer(let value):
            return value.description
        case .number(let value):
            return value.description
        case .bool(let value):
            return value.description
        case .object(let value):
            let entries = value.map { "\($0): \($1)" }.joined(separator: ", ")
            return "{\(entries)}"
        case .array(let value):
            let elements = value.map { "\($0)" }.joined(separator: ", ")
            return "[\(elements)]"
        case .null:
            return "null"
        }
    }
}
