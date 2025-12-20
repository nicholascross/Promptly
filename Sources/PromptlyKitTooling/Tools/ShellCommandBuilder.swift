import Foundation
import PromptlyKit

// MARK: - Entry point

public func shellCommands(@ShellCommandBuilder _ content: () -> [CommandSpec]) -> ShellCommandConfig {
    let entries = content().map { $0.toEntry() }
    return ShellCommandConfig(shellCommands: entries)
}

public func command(_ name: String) -> CommandSpec {
    CommandSpec(name: name)
}

// MARK: - Result builder

@resultBuilder
public enum ShellCommandBuilder {
    public static func buildBlock(_ components: CommandSpec...) -> [CommandSpec] { components }
    public static func buildOptional(_ component: [CommandSpec]?) -> [CommandSpec] { component ?? [] }
    public static func buildEither(first: [CommandSpec]) -> [CommandSpec] { first }
    public static func buildEither(second: [CommandSpec]) -> [CommandSpec] { second }
    public static func buildArray(_ components: [[CommandSpec]]) -> [CommandSpec] { components.flatMap { $0 } }
}

// MARK: - CommandSpec (immutable API, internal mutability for copy())

public struct CommandSpec {
    public var name: String
    public var descriptionText: String?
    public var executablePath: String?
    public var echoOutput: Bool?
    public var truncateOutput: Bool?
    public var argumentRows: [[String]]
    public var exclusiveArgumentTemplate: Bool?
    public var optIn: Bool?
    public var requiredProps: [(String, JSONSchema)]
    public var optionalProps: [(String, JSONSchema)]
    public var paramsDescriptionText: String?

    public init(
        name: String,
        descriptionText: String? = nil,
        executablePath: String? = nil,
        echoOutput: Bool? = nil,
        truncateOutput: Bool? = nil,
        argumentRows: [[String]] = [],
        exclusiveArgumentTemplate: Bool? = nil,
        optIn: Bool? = nil,
        requiredProps: [(String, JSONSchema)] = [],
        optionalProps: [(String, JSONSchema)] = [],
        paramsDescriptionText: String? = nil
    ) {
        self.name = name
        self.descriptionText = descriptionText
        self.executablePath = executablePath
        self.echoOutput = echoOutput
        self.truncateOutput = truncateOutput
        self.argumentRows = argumentRows
        self.exclusiveArgumentTemplate = exclusiveArgumentTemplate
        self.optIn = optIn
        self.requiredProps = requiredProps
        self.optionalProps = optionalProps
        self.paramsDescriptionText = paramsDescriptionText
    }

    // MARK: Modifiers

    public func describing(_ text: String) -> CommandSpec { copy { $0.descriptionText = text } }
    public func executable(_ path: String) -> CommandSpec { copy { $0.executablePath = path } }
    public func echoed(_ value: Bool = true) -> CommandSpec { copy { $0.echoOutput = value } }
    public func truncated(_ value: Bool = true) -> CommandSpec { copy { $0.truncateOutput = value } }
    public func exclusiveArgs(_ value: Bool = true) -> CommandSpec { copy { $0.exclusiveArgumentTemplate = value } }
    public func optedIn(_ value: Bool = true) -> CommandSpec { copy { $0.optIn = value } }

    public func argRow(_ parts: String...) -> CommandSpec {
        copy { $0.argumentRows.append(parts) }
    }

    public func require(_ name: String, _ schema: JSONSchema) -> CommandSpec {
        copy { $0.requiredProps.append((name, schema)) }
    }

    public func optional(_ name: String, _ schema: JSONSchema) -> CommandSpec {
        copy { $0.optionalProps.append((name, schema)) }
    }

    public func paramsDescription(_ text: String) -> CommandSpec {
        copy { $0.paramsDescriptionText = text }
    }

    // Build final ShellCommandConfigEntry
    public func toEntry() -> ShellCommandConfigEntry {
        ShellCommandConfigEntry(
            name: name,
            description: descriptionText ?? "",
            executable: executablePath ?? "",
            echoOutput: echoOutput,
            truncateOutput: truncateOutput,
            argumentTemplate: argumentRows,
            exclusiveArgumentTemplate: exclusiveArgumentTemplate,
            optIn: optIn,
            parameters: JSONSchema.object(
                requiredProperties: Dictionary(uniqueKeysWithValues: requiredProps),
                optionalProperties: Dictionary(uniqueKeysWithValues: optionalProps),
                description: paramsDescriptionText
            )
        )
    }

    // Copy-on-write helper used by modifiers
    private func copy(_ mutate: (inout CommandSpec) -> Void) -> CommandSpec {
        var selfCopy = self
        mutate(&selfCopy)
        return selfCopy
    }
}

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
