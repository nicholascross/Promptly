import Foundation
import PromptlyKitUtils

public extension JSONSchema {
    static func string(
        min: Int? = nil,
        max: Int? = nil,
        pattern: String? = nil,
        format: String? = nil,
        description: String? = nil
    ) -> JSONSchema {
        .string(minLength: min, maxLength: max, pattern: pattern, format: format, description: description)
    }

    static func integer(
        min: Int? = nil,
        max: Int? = nil,
        description: String? = nil
    ) -> JSONSchema {
        .integer(minimum: min, maximum: max, description: description)
    }
}
