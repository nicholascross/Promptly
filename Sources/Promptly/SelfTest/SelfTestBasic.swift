import ArgumentParser
import PromptlySelfTest

/// `promptly self-test basic` - run basic self tests
struct SelfTestBasic: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "basic",
        abstract: "Run core self tests that are safe and fast"
    )

    @OptionGroup
    var options: SelfTestOptions

    mutating func run() async throws {
        try await runSelfTests(level: .basic, options: options)
    }
}
