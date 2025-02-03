import Foundation
import ArgumentParser
import PromptlyKit
import Security

@main
struct Promptly: AsyncParsableCommand {

    @Flag(name: .long, help: "Run a setup to store your OpenAI/Open WebUI API token in the Keychain.")
    var setupToken = false

    @Argument(help: "A context string to pass to the system prompt.")
    var contextArgument: String?

    @Argument(help: "Override the default configuration path of ~/.config/promptly/config.json.")
    var configFile: String = "~/.config/promptly/config.json"

    mutating func run() async throws {
        let config = try Config.loadConfig(file: configFile)
        let prompter = Prompter(config: config)

        if setupToken {
            try await prompter.setupTokenAction()
            return
        }

        guard let contextArgument = contextArgument else {
            throw ValidationError("Usage: promptly <context-string>\\n")
        }

        // Pick which service to call
        if config.useOpenWebUI == true {
            // Use our new Open WebUI endpoint
            try await prompter.runChatOpenWebUIStream(contextArgument: contextArgument)
        } else {
            // Default to OpenAI
            try await prompter.runChatOpenAI(contextArgument: contextArgument)
        }
    }
}
