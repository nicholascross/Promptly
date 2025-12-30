import Foundation
import PromptlyKit
import PromptlyKitUtils

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

    private func copy(_ mutate: (inout CommandSpec) -> Void) -> CommandSpec {
        var selfCopy = self
        mutate(&selfCopy)
        return selfCopy
    }
}
