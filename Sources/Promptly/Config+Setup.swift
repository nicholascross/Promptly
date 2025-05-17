import Foundation

import PromptlyKit

extension Config {
    public static func setupToken(configURL: URL) async throws {
        print("Enter a name for your token: ", terminator: "")
        guard let tokenName = readLine(strippingNewline: true) else {
            print("Token name cannot be empty.")
            return
        }

        print("Enter your API token: ", terminator: "")
        guard let token = readLine(strippingNewline: true), !token.isEmpty else {
            print("Token cannot be empty.")
            return
        }

        do {
            try Keychain().setGenericPassword(
                account: tokenName,
                service: "Promptly",
                password: token
            )
            print("Token stored in Keychain under \(tokenName).")
        } catch {
            print("Failed to store token: \(error.localizedDescription)")
        }

        print("Updating config file with token name...")
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
