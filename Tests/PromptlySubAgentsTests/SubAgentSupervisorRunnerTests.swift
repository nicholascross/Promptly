import PromptlyKit
import PromptlyKitUtils
@testable import PromptlySubAgents
import Testing

struct SubAgentSupervisorRunnerTests {
    @Test
    func followUpWithInvalidResumeIdentifierTriggersSingleRecoveryRetry() async throws {
        let runner = SubAgentSupervisorRunner(maximumRecoveryAttempts: 1)
        let initialConversation = [
            PromptMessage(role: .user, content: .text("Start"))
        ]
        let validResumeIdentifier = "d628d61e-6f44-4eea-90be-c67ed0bb6c2a"
        var cycleCount = 0

        let finalCycle = try await runner.run(
            conversation: initialConversation,
            runCycle: { conversation in
                cycleCount += 1
                if cycleCount == 1 {
                    return makeCycle(
                        inputConversation: conversation,
                        toolName: "SubAgent-review-agent",
                        payload: JSONValue.object([
                            "needsMoreInformation": .bool(true),
                            "resumeId": .string("invalid")
                        ])
                    )
                }

                guard case let .text(recoveryMessage)? = conversation.last?.content else {
                    Issue.record("Expected recovery message as the latest user message.")
                    return makeCycle(
                        inputConversation: conversation,
                        toolName: "SubAgent-review-agent",
                        payload: JSONValue.object([
                            "needsMoreInformation": .bool(true),
                            "resumeId": .string(validResumeIdentifier)
                        ])
                    )
                }
                #expect(recoveryMessage == SubAgentSupervisorRecovery.recoveryPrompt(toolName: "SubAgent-review-agent"))

                return makeCycle(
                    inputConversation: conversation,
                    toolName: "SubAgent-review-agent",
                    payload: .object([
                        "needsMoreInformation": .bool(true),
                        "resumeId": .string(validResumeIdentifier)
                    ])
                )
            }
        )

        #expect(cycleCount == 2)
        #expect(SubAgentSupervisorRecovery.toolNeedingResumeRecovery(conversationEntries: finalCycle.conversationEntries) == nil)
    }

    @Test
    func followUpWithValidResumeIdentifierDoesNotRetry() async throws {
        let runner = SubAgentSupervisorRunner(maximumRecoveryAttempts: 1)
        let initialConversation = [
            PromptMessage(role: .user, content: .text("Start"))
        ]
        var cycleCount = 0

        _ = try await runner.run(
            conversation: initialConversation,
            runCycle: { conversation in
                cycleCount += 1
                return makeCycle(
                    inputConversation: conversation,
                    toolName: "SubAgent-review-agent",
                    payload: JSONValue.object([
                        "needsMoreInformation": .bool(true),
                        "resumeId": .string("d628d61e-6f44-4eea-90be-c67ed0bb6c2a")
                    ])
                )
            }
        )

        #expect(cycleCount == 1)
    }

    @Test
    func nonSubAgentToolOutputsDoNotTriggerRecovery() async throws {
        let runner = SubAgentSupervisorRunner(maximumRecoveryAttempts: 1)
        let initialConversation = [
            PromptMessage(role: .user, content: .text("Start"))
        ]
        var cycleCount = 0

        _ = try await runner.run(
            conversation: initialConversation,
            runCycle: { conversation in
                cycleCount += 1
                return makeCycle(
                    inputConversation: conversation,
                    toolName: "ListDirectory",
                    payload: JSONValue.object([
                        "needsSupervisorDecision": .bool(true)
                    ])
                )
            }
        )

        #expect(cycleCount == 1)
    }

    @Test
    func unresolvedRecoveryFailsWithClearError() async throws {
        let runner = SubAgentSupervisorRunner(maximumRecoveryAttempts: 1)
        let initialConversation = [
            PromptMessage(role: .user, content: .text("Start"))
        ]
        var cycleCount = 0

        do {
            _ = try await runner.run(
                conversation: initialConversation,
                runCycle: { conversation in
                    cycleCount += 1
                    return makeCycle(
                        inputConversation: conversation,
                        toolName: "SubAgent-review-agent",
                        payload: JSONValue.object([
                            "needsMoreInformation": .bool(true),
                            "resumeId": .string("invalid")
                        ])
                    )
                }
            )
            Issue.record("Expected unresolved resume recovery to throw an error.")
        } catch let error as SubAgentSupervisorRunnerError {
            switch error {
            case let .unresolvedResumeRecovery(toolName):
                #expect(toolName == "SubAgent-review-agent")
                #expect(error.localizedDescription.contains("recovery did not produce one"))
            }
        }

        #expect(cycleCount == 2)
    }

    private func makeCycle(
        inputConversation: [PromptMessage],
        toolName: String,
        payload: JSONValue
    ) -> SubAgentSupervisorRunCycle {
        let toolCallId = "call_1"
        let toolCall = PromptToolCall(
            id: toolCallId,
            name: toolName,
            arguments: .object([
                "task": .string("Collect details")
            ])
        )
        let conversationEntries = [
            PromptMessage(role: .assistant, content: .empty, toolCalls: [toolCall]),
            PromptMessage(role: .tool, content: .json(payload), toolCallId: toolCallId)
        ]
        return SubAgentSupervisorRunCycle(
            updatedConversation: inputConversation + conversationEntries,
            conversationEntries: conversationEntries
        )
    }
}
