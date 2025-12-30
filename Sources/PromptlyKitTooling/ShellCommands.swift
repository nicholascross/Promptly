import Foundation
import PromptlyKit

public func shellCommands(@ShellCommandBuilder _ content: () -> [CommandSpec]) -> ShellCommandConfig {
    let entries = content().map { $0.toEntry() }
    return ShellCommandConfig(shellCommands: entries)
}

public func command(_ name: String) -> CommandSpec {
    CommandSpec(name: name)
}
