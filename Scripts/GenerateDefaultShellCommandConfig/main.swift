import Foundation
import PromptlyKit
import PromptlyKitUtils

// A tool to generate a Swift source file embedding the default shell-command configuration
// from Docs/tools.json as Swift data objects.
func swiftLiteral(_ string: String) -> String {
    let escaped = string
        .replacingOccurrences(of: "\\", with: "\\\\")
        .replacingOccurrences(of: "\"", with: "\\\"")
        .replacingOccurrences(of: "\n", with: "\\n")
    return "\"\(escaped)\""
}

// Generate JSONSchema literals suitable for builder calls.
func schemaBuilderLiteral(_ schema: JSONSchema) -> String {
    switch schema {
    case let .string(_, _, _, _, description):
        let descLit = description.map { swiftLiteral($0) } ?? "nil"
        return ".string(description: \(descLit))"
    case let .integer(_, _, description):
        let descLit = description.map { swiftLiteral($0) } ?? "nil"
        return ".integer(description: \(descLit))"
    case let .boolean(description):
        let descLit = description.map { swiftLiteral($0) } ?? "nil"
        return ".boolean(description: \(descLit))"
    default:
        return schema.swiftRepresentation(indent: 0)
    }
}

extension JSONSchema {
    func swiftRepresentation(indent: Int = 0) -> String {
        let indentString = String(repeating: " ", count: indent)
        switch self {
        case let .object(required, optional, description):
            let reqEntries = required.map { key, schema in
                "\(indentString)    \"\(key)\": \(schema.swiftRepresentation(indent: indent + 4))"
            }.joined(separator: ",\n")
            let optEntries = optional.map { key, schema in
                "\(indentString)    \"\(key)\": \(schema.swiftRepresentation(indent: indent + 4))"
            }.joined(separator: ",\n")
            let descLiteral = description.map { swiftLiteral($0) } ?? "nil"
            var lines = [String]()
            lines.append("\(indentString)JSONSchema.object(")
            lines.append("\(indentString)    requiredProperties: [")
            lines.append(reqEntries)
            lines.append("\(indentString)    ],")
            lines.append("\(indentString)    optionalProperties: [")
            lines.append(optEntries)
            lines.append("\(indentString)    ],")
            lines.append("\(indentString)    description: \(descLiteral)")
            lines.append("\(indentString))")
            return lines.joined(separator: "\n")
        case let .array(items, description):
            let descLiteral = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.array(items: \(items.swiftRepresentation(indent: indent)), description: \(descLiteral))"
        case let .string(minLength, maxLength, pattern, format, description):
            let minLit = minLength.map { String($0) } ?? "nil"
            let maxLit = maxLength.map { String($0) } ?? "nil"
            let patLit = pattern.map { swiftLiteral($0) } ?? "nil"
            let fmtLit = format.map { swiftLiteral($0) } ?? "nil"
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.string(minLength: \(minLit), maxLength: \(maxLit), pattern: \(patLit), format: \(fmtLit), description: \(descLit))"
        case let .number(minimum, maximum, description):
            let minLit = minimum.map { String($0) } ?? "nil"
            let maxLit = maximum.map { String($0) } ?? "nil"
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.number(minimum: \(minLit), maximum: \(maxLit), description: \(descLit))"
        case let .integer(minimum, maximum, description):
            let minLit = minimum.map { String($0) } ?? "nil"
            let maxLit = maximum.map { String($0) } ?? "nil"
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.integer(minimum: \(minLit), maximum: \(maxLit), description: \(descLit))"
        case let .boolean(description):
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.boolean(description: \(descLit))"
        case let .null(description):
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.null(description: \(descLit))"
        case let .allOf(schemas, description):
            let inner = schemas.map { $0.swiftRepresentation(indent: indent) }.joined(separator: ", ")
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.allOf([\(inner)], description: \(descLit))"
        case let .anyOf(schemas, description):
            let inner = schemas.map { $0.swiftRepresentation(indent: indent) }.joined(separator: ", ")
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.anyOf([\(inner)], description: \(descLit))"
        case let .oneOf(schemas, description):
            let inner = schemas.map { $0.swiftRepresentation(indent: indent) }.joined(separator: ", ")
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.oneOf([\(inner)], description: \(descLit))"
        case let .not(schema, description):
            let descLit = description.map { swiftLiteral($0) } ?? "nil"
            return "\(indentString)JSONSchema.not(\(schema.swiftRepresentation(indent: indent)), description: \(descLit))"
        }
    }
}

func main() {
    do {
        let toolsURL = URL(fileURLWithPath: "Docs/tools.json")
        let data = try Data(contentsOf: toolsURL)
        let config = try JSONDecoder().decode(ShellCommandConfig.self, from: data)

        print("// Generated by GenerateDefaultShellCommandConfig")
        print("// Run: `swift run GenerateDefaultShellCommandConfig`")
        print()
        print("import Foundation")
        print("import PromptlyKit")
        print()
        print("public enum DefaultShellCommandConfig {")
        print("    public static let config: ShellCommandConfig = shellCommands {")

        for entry in config.shellCommands {
            let nameLit = swiftLiteral(entry.name)
            let descLit = swiftLiteral(entry.description)
            let execLit = swiftLiteral(entry.executable)

            print("        command(\(nameLit))")
            print("            .describing(\(descLit))")
            print("            .executable(\(execLit))")

            if entry.echoOutput == true {
                print("            .echoed()")
            }
            if entry.truncateOutput == true {
                print("            .truncated()")
            }
            if entry.exclusiveArgumentTemplate == true {
                print("            .exclusiveArgs()")
            }
            if entry.optIn == true {
                print("            .optedIn()")
            }

            for group in entry.argumentTemplate {
                let literals = group.map { swiftLiteral($0) }.joined(separator: ", ")
                print("            .argRow(\(literals))")
            }

            if case let .object(required, optional, paramsDesc) = entry.parameters {
                for (name, schema) in required {
                    let keyLit = swiftLiteral(name)
                    let schemaLit = schemaBuilderLiteral(schema)
                    print("            .require(\(keyLit), \(schemaLit))")
                }
                for (name, schema) in optional {
                    let keyLit = swiftLiteral(name)
                    let schemaLit = schemaBuilderLiteral(schema)
                    print("            .optional(\(keyLit), \(schemaLit))")
                }
                let paramsDescLit = swiftLiteral(paramsDesc ?? "")
                print("            .paramsDescription(\(paramsDescLit))")
            }

            print()
        }

        print("    }")
        print("}")
    } catch {
        fputs("Error: \(error)\n", stderr)
        exit(1)
    }
}

main()
