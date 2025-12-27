import Foundation
import PromptlyKitUtils

public struct SystemCredentialSource: CredentialSource {
    public init() {}

    public func resolveToken(
        providerKey: String,
        environmentKey: String?,
        tokenName: String?
    ) throws -> String {
        if let environmentKey, let environmentToken = ProcessInfo.processInfo.environment[environmentKey] {
            return environmentToken
        }
        if let tokenName {
            do {
                let keychainToken = try Keychain().genericPassword(
                    account: tokenName,
                    service: "Promptly"
                )
                guard let keychainToken else {
                    throw ConfigError.noKeychainToken(providerKey)
                }
                return keychainToken
            } catch let error as ConfigError {
                throw error
            } catch {
                throw ConfigError.keychainError(providerKey, error)
            }
        }
        throw ConfigError.noTokenConfiguration(providerKey)
    }
}
