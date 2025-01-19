import Foundation
import ArgumentParser
import PromptlyKit
import Security

@main
struct Promptly: AsyncParsableCommand {

    /// Flag to trigger setup mode for storing an API token in the Keychain.
    @Flag(name: .long, help: "Run a setup to store your OpenAI API token in the Keychain.")
    var setupToken = false

    /// The context string passed to the system prompt.
    @Argument(help: "A context string to pass to the system prompt.")
    var contextArgument: String?

    mutating func run() async throws {
        let prompter = Prompter()

        if setupToken {
            try await prompter.setupTokenAction()
            return
        }

        guard let contextArgument = contextArgument else {
            throw ValidationError("Usage: promptly <context-string>\n")
        }

        try await prompter.runChat(contextArgument: contextArgument)
    }
}
