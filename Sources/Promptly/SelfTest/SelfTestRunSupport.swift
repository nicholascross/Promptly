import ArgumentParser
import Foundation
import PromptlyKitUtils
import PromptlySelfTest

func runSelfTests(level: SelfTestLevel, options: SelfTestOptions) async throws {
    let configurationFileURL = URL(
        fileURLWithPath: options.configurationFile.expandingTilde
    ).standardizedFileURL
    let runner = SelfTestRunner(
        configurationFileURL: configurationFileURL,
        toolsFileName: options.toolsFileName
    )
    let summary = await runner.run(level: level)
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
    let data = try encoder.encode(summary)
    if let json = String(data: data, encoding: .utf8) {
        print(json)
    }
    if summary.status == .failed {
        throw ExitCode(2)
    }
}
