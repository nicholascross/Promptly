import ArgumentParser
import PromptlySelfTest

/// `promptly self-test tools` - run tool loading self tests
struct SelfTestTools: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "tools",
        abstract: "Run self tests for tool configuration loading and filtering"
    )

    @OptionGroup
    var options: SelfTestOptions

    mutating func run() async throws {
        try await runSelfTests(level: .tools, options: options)
    }
}
