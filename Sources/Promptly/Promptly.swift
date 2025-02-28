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

    @Option(name: .customLong("message"), help: "A message to send to the chat.")
    private var messages: [Message] = []

    @Option(name: [.customLong("canned"), .customShort("p")], help: "Use canned prompt as conext.")
    private var cannedContext: String?

    mutating func run() async throws {
        let configURL = URL(fileURLWithPath: configFile.expandingTilde).standardizedFileURL
        guard FileManager.default.fileExists(atPath: configURL.path) else {
            throw PrompterError.missingConfiguration
        }

        if setupToken {
            try await Config.setupToken(configURL: configURL)
            return
        }

        let config = try Config.loadConfig(url: configURL)
        let prompter = try Prompter(config: config, rawOutput: rawOutput)

        guard messages.isEmpty else {
            try await prompter.runChatStream(messages: messages.rawMessages)
            return
        }

        let prompt: String
        if let cannedContext = cannedContext {
            prompt = try loadCannedPrompt(name: cannedContext)
        } else {
            guard let contextArgument = contextArgument else {
                throw ValidationError("Usage: promptly <context-string>\\n")
            }
            prompt = contextArgument
        }

        try await prompter.runChatStream(contextArgument: prompt)
    }

    private func loadCannedPrompt(name: String) throws -> String {
        let cannedURL = URL(fileURLWithPath: "~/.config/promptly/canned/\(name).txt".expandingTilde)
            .standardizedFileURL
        guard FileManager.default.fileExists(atPath: cannedURL.path) else {
            throw ValidationError("Canned prompt \(cannedURL) not found.")
        }
        let data = try Data(contentsOf: cannedURL)
        return String(data: data, encoding: .utf8) ?? ""
    }
}

private enum Message: ExpressibleByArgument {
    case user(String)
    case system(String)
    case assistant(String)

    init?(argument: String) {
        if argument.hasPrefix("user:") {
            self = .user(argument.dropFirst(5).description)
        } else if argument.hasPrefix("system:") {
            self = .system(argument.dropFirst(7).description)
        } else if argument.hasPrefix("assistant:") {
            self = .assistant(argument.dropFirst(10).description)
        } else {
            return nil
        }
    }
}

private extension [Message] {
    var rawMessages: [[String: String]] {
        map { message in
            switch message {
            case .user(let content):
                return ["role": "user", "content": content]
            case .system(let content):
                return ["role": "system", "content": content]
            case .assistant(let content):
                return ["role": "assistant", "content": content]
            }
        }
    }
}

private extension String {
    var expandingTilde: String {
        guard self.hasPrefix("~") else { return self }
        return self.replacingOccurrences(
            of: "~",
            with: FileManager.default.homeDirectoryForCurrentUser.path,
            range: self.startIndex..<self.index(after: self.startIndex)
        )
    }
}
