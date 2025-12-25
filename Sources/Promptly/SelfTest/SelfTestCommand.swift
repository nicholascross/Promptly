import ArgumentParser

/// `promptly self-test` group
struct SelfTestCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "self-test",
        abstract: "Run built in self tests",
        subcommands: [SelfTestList.self, SelfTestBasic.self, SelfTestTools.self, SelfTestAgents.self]
    )
}
