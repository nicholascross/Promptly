import Foundation

import PromptlyKit

extension Config {
    public static func setupToken(configURL: URL) async throws {
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
        try updateConfig(tokenName: tokenName, configURL: configURL)
    }

    private static func updateConfig(tokenName: String, configURL: URL) throws {
        let raw = try Data(contentsOf: configURL)
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
        try updatedData.write(to: configURL)
    }
}
