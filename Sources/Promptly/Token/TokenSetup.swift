import ArgumentParser
import Foundation
import PromptlyKit
import PromptlyKitUtils

private let fileManager: FileManagerProtocol = FileManager.default

struct TokenSetup: AsyncParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "setup",
        abstract: "Store or update a provider token in Keychain"
    )

    @Option(
        name: .customShort("c"),
        help: "Override the default configuration path of ~/.config/promptly/config.json."
    )
    var configFile: String = "~/.config/promptly/config.json"

    mutating func run() async throws {
        let configURL = try resolveConfigURL()
        try await Config.setupToken(configURL: configURL, fileManager: fileManager)
    }

    private func resolveConfigURL() throws -> URL {
        let configURL = URL(fileURLWithPath: configFile.expandingTilde).standardizedFileURL
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw PrompterError.missingConfiguration
        }
        return configURL
    }
}
