import PromptlyKit

struct TestCredentialSource: CredentialSource {
    let token: String

    func resolveToken(
        providerKey _: String,
        environmentKey _: String?,
        tokenName _: String?
    ) throws -> String {
        token
    }
}
