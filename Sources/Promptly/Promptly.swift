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

    mutating func run() async throws {
        let prompter = Prompter()

        if setupToken {
            try await prompter.setupTokenAction()
            return
        }

        guard let contextArgument = contextArgument else {
            throw ValidationError("Usage: promptly <context-string>\\n")
        }

        // Load config; pick which service to call
        let config = try Config.loadConfig()
        if config.useOpenWebUI == true {
            // Use our new Open WebUI endpoint
            try await prompter.runChatOpenWebUIStream(contextArgument: contextArgument)
        } else {
            // Default to OpenAI
            try await prompter.runChatOpenAI(contextArgument: contextArgument)
        }
    }
}
