import Foundation

enum ConfigError: Error, LocalizedError {
    case couldNotResolveURL(String)
    case noKeychainToken(String)
    case keychainError(String, Error)
    case noTokenConfiguration(String)
    case missingCredentialSource

    var errorDescription: String? {
        switch self {
        case let .couldNotResolveURL(key):
            return "Could not resolve URL for provider '\(key)'"
        case let .noKeychainToken(key):
            return "No keychain token found for provider '\(key)'"
        case let .keychainError(key, error):
            return "Unable to fetch keychain token for provider '\(key)': \(error)"
        case let .noTokenConfiguration(key):
            return "No token configuration for provider '\(key)'"
        case .missingCredentialSource:
            return "Credential source was not provided during configuration decoding."
        }
    }
}
