import Foundation

@resultBuilder
public enum ShellCommandBuilder {
    public static func buildBlock(_ components: CommandSpec...) -> [CommandSpec] { components }
    public static func buildOptional(_ component: [CommandSpec]?) -> [CommandSpec] { component ?? [] }
    public static func buildEither(first: [CommandSpec]) -> [CommandSpec] { first }
    public static func buildEither(second: [CommandSpec]) -> [CommandSpec] { second }
    public static func buildArray(_ components: [[CommandSpec]]) -> [CommandSpec] { components.flatMap { $0 } }
}
