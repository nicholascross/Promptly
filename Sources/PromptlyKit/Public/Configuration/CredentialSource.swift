import Foundation

public protocol CredentialSource: Sendable {
    func resolveToken(
        providerKey: String,
        environmentKey: String?,
        tokenName: String?
    ) throws -> String
}

public extension CodingUserInfoKey {
    static let promptlyCredentialSource = CodingUserInfoKey(rawValue: "promptly.credentialSource")!
}
