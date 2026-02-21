import PromptlyKitUtils
@testable import PromptlySubAgents
import Testing

struct SubAgentSupervisorRecoveryTests {
    @Test
    func requiresRecoveryWhenFollowUpIsRequestedWithoutResumeIdentifier() {
        let payload: JSONValue = .object([
            "needsMoreInformation": .bool(true)
        ])

        #expect(SubAgentSupervisorRecovery.requiresResumeRecovery(payload: payload))
    }

    @Test
    func doesNotRequireRecoveryWhenFollowUpIncludesValidResumeIdentifier() {
        let payload: JSONValue = .object([
            "needsSupervisorDecision": .bool(true),
            "resumeId": .string(" d628d61e-6f44-4eea-90be-c67ed0bb6c2a ")
        ])

        #expect(!SubAgentSupervisorRecovery.requiresResumeRecovery(payload: payload))
    }

    @Test
    func doesNotRequireRecoveryWhenFollowUpIsNotRequested() {
        let payload: JSONValue = .object([
            "needsMoreInformation": .bool(false),
            "needsSupervisorDecision": .bool(false),
            "resumeId": .string("invalid")
        ])

        #expect(!SubAgentSupervisorRecovery.requiresResumeRecovery(payload: payload))
    }
}
