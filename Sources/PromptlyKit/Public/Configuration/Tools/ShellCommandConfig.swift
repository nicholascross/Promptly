import Foundation

public struct ShellCommandConfig: Codable, Sendable {
    public var shellCommands: [ShellCommandConfigEntry]

    public init(shellCommands: [ShellCommandConfigEntry]) {
        self.shellCommands = shellCommands
    }
}
