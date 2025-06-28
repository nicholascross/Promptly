import Foundation

public indirect enum JSONSchema: Codable, Sendable {
    case object(
        requiredProperties: [String: JSONSchema],
        optionalProperties: [String: JSONSchema],
        description: String?
    )

    case array(items: JSONSchema, description: String?)

    case string(
        minLength: Int?,
        maxLength: Int?,
        pattern: String?,
        format: String?,
        description: String?
    )

    case number(minimum: Double?, maximum: Double?, description: String?)
    case integer(minimum: Int?, maximum: Int?, description: String?)
    case boolean(description: String?)
    case null(description: String?)
    case allOf([JSONSchema], description: String?)
    case anyOf([JSONSchema], description: String?)
    case oneOf([JSONSchema], description: String?)
    case not(JSONSchema, description: String?)

    enum CodingKeys: String, CodingKey {
        case type, properties, required, items
        case minLength, maxLength, pattern, format
        case minimum, maximum
        case allOf, anyOf, oneOf, not
        case description
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)

        switch self {
        case let .allOf(schemas, desc):
            try container.encode(schemas, forKey: .allOf)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .anyOf(schemas, desc):
            try container.encode(schemas, forKey: .anyOf)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .oneOf(schemas, desc):
            try container.encode(schemas, forKey: .oneOf)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .not(schema, desc):
            try container.encode(schema, forKey: .not)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .object(required, optional, desc):
            try container.encode("object", forKey: .type)
            try container.encodeIfPresent(desc, forKey: .description)

            let merged = required.merging(optional) { first, _ in first }
            try container.encode(merged, forKey: .properties)

            if !required.isEmpty {
                try container.encode(Array(required.keys), forKey: .required)
            }

        case let .array(items, desc):
            try container.encode("array", forKey: .type)
            try container.encode(items, forKey: .items)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .string(minL, maxL, pattern, format, desc):
            try container.encode("string", forKey: .type)
            try container.encodeIfPresent(minL, forKey: .minLength)
            try container.encodeIfPresent(maxL, forKey: .maxLength)
            try container.encodeIfPresent(pattern, forKey: .pattern)
            try container.encodeIfPresent(format, forKey: .format)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .number(min, max, desc):
            try container.encode("number", forKey: .type)
            try container.encodeIfPresent(min, forKey: .minimum)
            try container.encodeIfPresent(max, forKey: .maximum)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .integer(min, max, desc):
            try container.encode("integer", forKey: .type)
            try container.encodeIfPresent(min, forKey: .minimum)
            try container.encodeIfPresent(max, forKey: .maximum)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .boolean(desc):
            try container.encode("boolean", forKey: .type)
            try container.encodeIfPresent(desc, forKey: .description)

        case let .null(desc):
            try container.encode("null", forKey: .type)
            try container.encodeIfPresent(desc, forKey: .description)
        }
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        // check combinators first
        if container.contains(.allOf) {
            let schemas = try container.decode([JSONSchema].self, forKey: .allOf)
            let desc = try container.decodeIfPresent(String.self, forKey: .description)
            self = .allOf(schemas, description: desc); return
        }
        if container.contains(.anyOf) {
            let schemas = try container.decode([JSONSchema].self, forKey: .anyOf)
            let desc = try container.decodeIfPresent(String.self, forKey: .description)
            self = .anyOf(schemas, description: desc); return
        }
        if container.contains(.oneOf) {
            let schemas = try container.decode([JSONSchema].self, forKey: .oneOf)
            let desc = try container.decodeIfPresent(String.self, forKey: .description)
            self = .oneOf(schemas, description: desc); return
        }
        if container.contains(.not) {
            let schema = try container.decode(JSONSchema.self, forKey: .not)
            let desc = try container.decodeIfPresent(String.self, forKey: .description)
            self = .not(schema, description: desc); return
        }

        // fall back to “type”-based
        let type = try container.decode(String.self, forKey: .type)
        switch type {
        case "object":
            let allProps = try container.decode([String: JSONSchema].self, forKey: .properties)
            let reqKeys = try container.decodeIfPresent([String].self, forKey: .required) ?? []
            var requiredProps = [String: JSONSchema]()
            for key in reqKeys {
                if let property = allProps[key] { requiredProps[key] = property }
            }
            let optionalProps = allProps.filter { !reqKeys.contains($0.key) }
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .object(
                requiredProperties: requiredProps,
                optionalProperties: optionalProps,
                description: description
            )

        case "array":
            let items = try container.decode(JSONSchema.self, forKey: .items)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .array(items: items, description: description)

        case "string":
            let minL = try container.decodeIfPresent(Int.self, forKey: .minLength)
            let maxL = try container.decodeIfPresent(Int.self, forKey: .maxLength)
            let pattern = try container.decodeIfPresent(String.self, forKey: .pattern)
            let format = try container.decodeIfPresent(String.self, forKey: .format)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .string(minLength: minL, maxLength: maxL, pattern: pattern, format: format, description: description)

        case "number":
            let min = try container.decodeIfPresent(Double.self, forKey: .minimum)
            let max = try container.decodeIfPresent(Double.self, forKey: .maximum)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .number(minimum: min, maximum: max, description: description)

        case "integer":
            let min = try container.decodeIfPresent(Int.self, forKey: .minimum)
            let max = try container.decodeIfPresent(Int.self, forKey: .maximum)
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .integer(minimum: min, maximum: max, description: description)

        case "boolean":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .boolean(description: description)

        case "null":
            let description = try container.decodeIfPresent(String.self, forKey: .description)
            self = .null(description: description)

        default:
            throw DecodingError.dataCorruptedError(
                forKey: .type, in: container,
                debugDescription: "Unsupported type: \(type)"
            )
        }
    }

    func isRequiredProperty(_ name: String) -> Bool {
        switch self {
        case let .object(required, _, _):
            return required.keys.contains(name)
        default:
            return false
        }
    }
}
