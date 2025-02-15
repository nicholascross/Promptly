import Foundation
import ArgumentParser
import PromptlyKit

@main
struct Promptly: AsyncParsableCommand {

    @Argument(help: "A context string to pass to the system prompt.")
    var contextArgument: String?

    @Option(name: .customShort("c"), help: "Override the default configuration path of ~/.config/promptly/config.json.")
    var configFile: String = "~/.config/promptly/config.json"

    @Flag(name: .customLong("setup-token"), help: "Setup a new token.")
    var setupToken: Bool = false

    @Flag(name: .customLong("raw-output"), help: "Output raw responses.")
    var rawOutput: Bool = false

    mutating func run() async throws {
        let configURL = URL(fileURLWithPath: NSString(string: configFile).expandingTildeInPath).standardizedFileURL
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw PrompterError.missingConfiguration
        }

        if setupToken {
            try await Config.setupToken(configURL: configURL)
            return
        }

        let config = try Config.loadConfig(url: configURL)

        guard let contextArgument = contextArgument else {
            throw ValidationError("Usage: promptly <context-string>\\n")
        }

        let prompter = try Prompter(config: config, rawOutput: rawOutput)
        try await prompter.runChatStream(contextArgument: contextArgument)
    }
}
