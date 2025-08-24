import Foundation

public struct ShellCommandConfig: Codable {
    public var shellCommands: [ShellCommandConfigEntry]

    public init(shellCommands: [ShellCommandConfigEntry]) {
        self.shellCommands = shellCommands
    }
}
