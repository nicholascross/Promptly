import ArgumentParser

/// `promptly token` group
struct TokenCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "token",
        abstract: "Manage stored provider tokens",
        subcommands: [TokenSetup.self]
    )
}
