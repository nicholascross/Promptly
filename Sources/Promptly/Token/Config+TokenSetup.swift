import Foundation
import PromptlyKit
import PromptlyKitUtils

extension Config {
    static func setupToken(
        configURL: URL,
        fileManager: FileManagerProtocol = FileManager.default
    ) async throws {
        Logger.prompt("Enter a name for your token: ")
        guard let tokenName = readLine(strippingNewline: true), !tokenName.isEmpty else {
            Logger.log("Token name cannot be empty.", level: .error)
            return
        }

        Logger.prompt("Enter your API token: ")
        guard let token = readLine(strippingNewline: true), !token.isEmpty else {
            Logger.log("Token cannot be empty.", level: .error)
            return
        }

        do {
            try Keychain().setGenericPassword(
                account: tokenName,
                service: "Promptly",
                password: token
            )
            Logger.log("Token stored in Keychain under \(tokenName).", level: .success)
        } catch {
            Logger.log("Failed to store token: \(error.localizedDescription)", level: .error)
        }

        Logger.log("Updating config file with token name...", level: .info)
        try updateConfig(tokenName: tokenName, configURL: configURL, fileManager: fileManager)
    }

    private static func updateConfig(
        tokenName: String,
        configURL: URL,
        fileManager: FileManagerProtocol
    ) throws {
        let raw = try fileManager.readData(at: configURL)
        guard
            var document = try JSONSerialization.jsonObject(with: raw, options: []) as? [String: Any],
            let providerKey = document["provider"] as? String,
            var providers = document["providers"] as? [String: Any],
            var spec = providers[providerKey] as? [String: Any]
        else {
            throw PrompterError.invalidConfiguration
        }

        spec["tokenName"] = tokenName
        providers[providerKey] = spec
        document["providers"] = providers

        let updatedData = try JSONSerialization.data(
            withJSONObject: document,
            options: [.prettyPrinted]
        )
        try fileManager.writeData(updatedData, to: configURL)
    }
}
