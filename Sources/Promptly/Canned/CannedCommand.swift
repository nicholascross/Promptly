import ArgumentParser

/// `promptly canned` group
struct CannedCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "canned",
        abstract: "Manage canned prompts",
        subcommands: [CannedList.self, CannedAdd.self, CannedRemove.self]
    )
}
