import Foundation
import PromptlyKit

struct SelfTestCredentialSource: CredentialSource {
    private let baseCredentialSource: any CredentialSource
    private let environment: [String: String]

    init(
        baseCredentialSource: any CredentialSource = SystemCredentialSource(),
        environment: [String: String] = ProcessInfo.processInfo.environment
    ) {
        self.baseCredentialSource = baseCredentialSource
        self.environment = environment
    }

    func resolveToken(
        providerKey: String,
        environmentKey: String?,
        tokenName: String?
    ) throws -> String {
        let environmentKeys = suggestedEnvironmentKeys(
            providerKey: providerKey,
            explicitEnvironmentKey: environmentKey
        )

        if let environmentToken = tokenFromEnvironment(keys: environmentKeys) {
            return environmentToken
        }

        do {
            return try baseCredentialSource.resolveToken(
                providerKey: providerKey,
                environmentKey: environmentKey,
                tokenName: tokenName
            )
        } catch {
            throw SelfTestCredentialError.missingCredential(
                providerKey: providerKey,
                attemptedEnvironmentKeys: environmentKeys,
                underlyingError: error
            )
        }
    }

    private func suggestedEnvironmentKeys(
        providerKey: String,
        explicitEnvironmentKey: String?
    ) -> [String] {
        var keys: [String] = []
        if let explicitEnvironmentKey {
            let trimmed = explicitEnvironmentKey.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                keys.append(trimmed)
            }
        }
        if let fallbackKey = Self.defaultEnvironmentKeyByProvider[providerKey.lowercased()],
           !keys.contains(fallbackKey) {
            keys.append(fallbackKey)
        }
        return keys
    }

    private func tokenFromEnvironment(keys: [String]) -> String? {
        for key in keys {
            guard let value = environment[key] else {
                continue
            }
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                return trimmed
            }
        }
        return nil
    }

    private static let defaultEnvironmentKeyByProvider: [String: String] = [
        "openai": "OPENAI_API_KEY",
        "anthropic": "ANTHROPIC_API_KEY",
        "google": "GEMINI_API_KEY",
        "mistral": "MISTRAL_API_KEY",
        "xai": "XAI_API_KEY"
    ]
}

enum SelfTestCredentialError: LocalizedError {
    case missingCredential(
        providerKey: String,
        attemptedEnvironmentKeys: [String],
        underlyingError: Error
    )

    var errorDescription: String? {
        switch self {
        case let .missingCredential(providerKey, attemptedEnvironmentKeys, underlyingError):
            let environmentMessage: String
            if attemptedEnvironmentKeys.isEmpty {
                environmentMessage = "No environment variable key was configured for this provider."
            } else {
                environmentMessage = "Checked environment variables: \(attemptedEnvironmentKeys.joined(separator: ", "))."
            }
            return """
            Could not resolve credentials for provider '\(providerKey)'.
            \(environmentMessage)
            Credential source lookup failed with: \(underlyingError).
            Set a provider token environment variable and rerun the self test, which is recommended when keychain access is unavailable in sandboxed sessions.
            """
        }
    }
}
