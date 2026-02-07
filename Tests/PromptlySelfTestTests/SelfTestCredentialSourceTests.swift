import PromptlyKit
@testable import PromptlySelfTest
import Testing

struct SelfTestCredentialSourceTests {
    @Test
    func prefersConfiguredEnvironmentKey() throws {
        let credentialSource = SelfTestCredentialSource(
            baseCredentialSource: ThrowingCredentialSource(),
            environment: ["CUSTOM_OPENAI_TOKEN": "environment-token"]
        )

        let token = try credentialSource.resolveToken(
            providerKey: "openai",
            environmentKey: "CUSTOM_OPENAI_TOKEN",
            tokenName: "token"
        )

        #expect(token == "environment-token")
    }

    @Test
    func usesDefaultProviderEnvironmentFallback() throws {
        let credentialSource = SelfTestCredentialSource(
            baseCredentialSource: ThrowingCredentialSource(),
            environment: ["OPENAI_API_KEY": "fallback-token"]
        )

        let token = try credentialSource.resolveToken(
            providerKey: "openai",
            environmentKey: nil,
            tokenName: "token"
        )

        #expect(token == "fallback-token")
    }

    @Test
    func reportsActionableErrorWhenCredentialLookupFails() {
        let credentialSource = SelfTestCredentialSource(
            baseCredentialSource: ThrowingCredentialSource(),
            environment: [:]
        )

        do {
            _ = try credentialSource.resolveToken(
                providerKey: "openai",
                environmentKey: nil,
                tokenName: "token"
            )
            Issue.record("Expected credential resolution to fail when keychain and environment are unavailable.")
        } catch let error as SelfTestCredentialError {
            let description = error.localizedDescription
            #expect(description.contains("OPENAI_API_KEY"))
            #expect(description.contains("sandboxed sessions"))
        } catch {
            Issue.record("Unexpected error type: \(error)")
        }
    }
}

private struct ThrowingCredentialSource: CredentialSource {
    func resolveToken(
        providerKey _: String,
        environmentKey _: String?,
        tokenName _: String?
    ) throws -> String {
        throw ThrowingCredentialSourceError.notAvailable
    }
}

private enum ThrowingCredentialSourceError: Error {
    case notAvailable
}
