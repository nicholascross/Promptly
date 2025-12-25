import ArgumentParser
import PromptlySelfTest

/// `promptly self-test agents` - run sub agent self tests
struct SelfTestAgents: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "agents",
        abstract: "Run self tests for sub agent configuration loading"
    )

    @OptionGroup
    var options: SelfTestOptions

    mutating func run() async throws {
        try await runSelfTests(level: .agents, options: options)
    }
}
