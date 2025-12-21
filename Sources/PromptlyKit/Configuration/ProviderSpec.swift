import Foundation
import PromptlyKitUtils

struct ProviderSpec: Codable {
    let name: String
    let baseURL: String?
    let scheme: String?
    let host: String?
    let port: Int?
    let path: String?
    let responsesPath: String?
    let chatPath: String?
    let envKey: String?
    let tokenName: String?

    func resolveResponsesURL(providerKey: String) throws -> URL {
        try resolveURL(providerKey: providerKey, kind: .responses)
    }

    func resolveChatCompletionsURL(providerKey: String) throws -> URL {
        try resolveURL(providerKey: providerKey, kind: .chatCompletions)
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

    private enum PathKind {
        case responses
        case chatCompletions
    }

    private func resolveURL(providerKey: String, kind: PathKind) throws -> URL {
        if let base = baseURL, let baseURL = URL(string: base) {
            return baseURL.appendingPathComponent(pathComponent(for: kind, baseURLProvided: true))
        }

        guard let scheme, let host else {
            throw ConfigError.couldNotResolveURL(providerKey)
        }

        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port {
            components.port = port
        }
        components.path = "/" + pathComponent(for: kind, baseURLProvided: false)

        if let url = components.url {
            return url
        }

        throw ConfigError.couldNotResolveURL(providerKey)
    }

    private func pathComponent(for kind: PathKind, baseURLProvided: Bool) -> String {
        switch kind {
        case .responses:
            if baseURLProvided {
                return responsesPath ?? "responses"
            }
            return responsesPath ?? path ?? "v1/responses"

        case .chatCompletions:
            if baseURLProvided {
                if let chatPath {
                    return chatPath
                }
                if let path, let inferred = inferChatPath(from: path) {
                    return inferred
                }
                return "chat/completions"
            }

            if let chatPath {
                return chatPath
            }
            if let path, let inferred = inferChatPath(from: path) {
                return inferred
            }
            return "v1/chat/completions"
        }
    }

    private func inferChatPath(from path: String) -> String? {
        if path.contains("chat/completions") {
            return path
        }
        if path.contains("responses") {
            return path.replacingOccurrences(of: "responses", with: "chat/completions")
        }
        return nil
    }
}
