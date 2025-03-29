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
        let config = try Config.loadConfig(url: configURL)

        let updatedConfig = Config(
            organizationId: config.organizationId,
            host: config.host,
            port: config.port,
            scheme: config.scheme,
            model: config.model,
            tokenName: tokenName
        )

        let data = try JSONEncoder().encode(updatedConfig)
        try data.write(to: configURL)
    }
}
