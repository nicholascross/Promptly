@testable import Promptly
import PromptlySubAgents
import Testing

struct AgentRunSupervisorPromptTests {
    @Test
    func includesSupervisorRoutingGuidance() {
        let toolName = "SubAgent-review-agent"

        let prompt = AgentRun.supervisorSystemPrompt(toolName: toolName)

        #expect(prompt.contains(SubAgentRoutingGuidance.delegatedToolRoutingReminder(toolName: toolName)))
        #expect(prompt.contains(SubAgentRoutingGuidance.ambiguousRoutingReminder))
        #expect(prompt.contains("When delegation is appropriate and you have enough information, call the tool exactly once."))
        #expect(prompt.contains("For \(SubAgentRoutingGuidance.directHandlingCriteria) that do not require delegated work, respond directly without tool calling."))
        #expect(prompt.contains("For a new sub agent task, omit resumeId entirely."))
        #expect(prompt.contains("Include resumeId only when continuing a prior sub agent run, and copy the exact value from the prior tool output."))
    }
}
