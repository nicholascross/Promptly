import Foundation

struct ProviderSpec: Codable {
    let name: String
    let baseURL: String?
    let scheme: String?
    let host: String?
    let port: Int?
    let path: String?
    let envKey: String?
    let tokenName: String?

    func resolveChatCompletionsURL(providerKey: String) throws -> URL {
        if let base = baseURL, let resolved = URL(string: base) {
            return resolved.appendingPathComponent("chat/completions")
        } else if
            let scheme = scheme,
            let host = host,
            let port = port,
            let resolved = URL(string: "\(scheme)://\(host):\(port)/\(path ?? "v1/chat/completions")")
        {
            return resolved
        } else {
            throw ConfigError.couldNotResolveURL(providerKey)
        }
    }

    func resolveToken(providerKey: String) throws -> String {
        if
            let envKey = envKey,
            let envToken = ProcessInfo.processInfo.environment[envKey]
        {
            return envToken
        } else if let tokenName = tokenName {
            do {
                let keychainToken = try Keychain().genericPassword(
                    account: tokenName,
                    service: "Promptly"
                )
                guard let keychainToken else {
                    throw ConfigError.noKeychainToken(providerKey)
                }
                return keychainToken
            } catch {
                throw ConfigError.keychainError(providerKey, error)
            }
        } else {
            throw ConfigError.noTokenConfiguration(providerKey)
        }
    }
}
