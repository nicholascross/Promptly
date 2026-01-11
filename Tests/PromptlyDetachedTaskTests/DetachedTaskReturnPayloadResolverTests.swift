import Foundation
import PromptlyKit
import PromptlyKitUtils
@testable import PromptlyDetachedTask
import Testing

struct DetachedTaskReturnPayloadResolverTests {
    @Test
    func extractReturnPayloadPrefersLastToolOutput() throws {
        let resolver = DetachedTaskReturnPayloadResolver(
            returnToolName: "ReturnToSupervisor"
        )
        let firstArguments = try payloadValue(
            result: "first-result",
            summary: "first-summary"
        )
        let secondArguments = try payloadValue(
            result: "second-result",
            summary: "second-summary"
        )
        let firstOutput = try payloadValue(
            result: "first-output",
            summary: "first-output-summary"
        )
        let secondOutput = try payloadValue(
            result: "second-output",
            summary: "second-output-summary"
        )

        let toolCalls = [
            PromptToolCall(
                id: "call-1",
                name: "ReturnToSupervisor",
                arguments: firstArguments
            ),
            PromptToolCall(
                id: "call-2",
                name: "ReturnToSupervisor",
                arguments: secondArguments
            )
        ]
        let conversationEntries = [
            PromptMessage(
                role: .assistant,
                content: .text(""),
                toolCalls: toolCalls
            ),
            PromptMessage(
                role: .tool,
                content: .json(firstOutput),
                toolCallId: "call-1"
            ),
            PromptMessage(
                role: .tool,
                content: .json(secondOutput),
                toolCallId: "call-2"
            )
        ]

        let payload = resolver.extractReturnPayload(
            from: conversationEntries
        )

        #expect(payload?.summary == "second-output-summary")
        #expect(payload?.result == "second-output")
    }

    @Test
    func resolvePayloadUsesFallbackWhenMissing() {
        let resolver = DetachedTaskReturnPayloadResolver(
            returnToolName: "ReturnToSupervisor"
        )
        let conversationEntries = [
            PromptMessage(
                role: .assistant,
                content: .text("Waiting on more details.")
            )
        ]

        let resolution = resolver.resolvePayload(
            candidate: nil,
            conversationEntries: conversationEntries
        )

        #expect(resolution.didUseFallback)
        #expect(resolution.payload.needsSupervisorDecision == true)
        #expect(resolution.payload.summary == "Sub agent did not complete the task.")
        #expect(
            resolution.payload.decisionReason ==
                "Sub agent did not call ReturnToSupervisor after reminder."
        )
        #expect(
            resolution.payload.supervisorMessage?.content.contains("Waiting on more details.") == true
        )
    }
}

private func payloadValue(
    result: String,
    summary: String
) throws -> JSONValue {
    let payload = DetachedTaskReturnPayload(
        result: result,
        summary: summary,
        artifacts: nil,
        evidence: nil,
        confidence: nil,
        needsMoreInformation: nil,
        requestedInformation: nil,
        needsSupervisorDecision: nil,
        decisionReason: nil,
        nextActionAdvice: nil,
        resumeId: nil,
        logPath: nil,
        supervisorMessage: nil
    )
    return try JSONValue(payload)
}
