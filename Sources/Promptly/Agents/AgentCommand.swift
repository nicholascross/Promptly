import ArgumentParser

/// `promptly agent` group
struct AgentCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agent",
        abstract: "Manage sub agent configurations",
        subcommands: [
            AgentList.self,
            AgentView.self,
            AgentAdd.self,
            AgentRemove.self,
            AgentInstall.self
        ]
    )
}
