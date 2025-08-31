import ArgumentParser

/// `promptly tool` group
struct ToolCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tool",
        abstract: "Manage registered CLI tools",
        subcommands: [ToolList.self, ToolView.self, ToolAdd.self, ToolRemove.self, ToolInstall.self]
    )
}
