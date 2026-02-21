import Foundation
@testable import PromptlySubAgents
import PromptlyKitUtils
import Testing

struct SubAgentToolRequestTests {
    @Test
    func forkedContextAllowsMissingTranscriptWhenResumeIdentifierIsValid() throws {
        let validResumeIdentifier = "d628d61e-6f44-4eea-90be-c67ed0bb6c2a"
        let payload: JSONValue = .object([
            "task": .string("Continue investigation"),
            "handoffStrategy": .string("forkedContext"),
            "resumeId": .string(" \(validResumeIdentifier) ")
        ])

        let request = try decodeRequest(from: payload)

        #expect(request.task == "Continue investigation")
        #expect(request.resumeId == " \(validResumeIdentifier) ")
        switch request.handoff {
        case let .forkedContext(entries):
            #expect(entries.isEmpty)
        case .contextPack:
            Issue.record("Expected forkedContext handoff.")
        }
    }

    @Test
    func forkedContextRequiresTranscriptWhenResumeIdentifierIsMissing() throws {
        let payload: JSONValue = .object([
            "task": .string("Continue investigation"),
            "handoffStrategy": .string("forkedContext")
        ])

        do {
            _ = try decodeRequest(from: payload)
            Issue.record("Expected missing forked transcript validation error.")
        } catch let error as SubAgentToolError {
            if case .missingForkedTranscript = error {
                // Expected error.
            } else {
                Issue.record("Unexpected sub agent tool error: \(error)")
            }
        }
    }

    @Test
    func forkedContextRequiresTranscriptWhenResumeIdentifierIsInvalid() throws {
        let payload: JSONValue = .object([
            "task": .string("Continue investigation"),
            "handoffStrategy": .string("forkedContext"),
            "resumeId": .string("not-a-uuid")
        ])

        do {
            _ = try decodeRequest(from: payload)
            Issue.record("Expected missing forked transcript validation error.")
        } catch let error as SubAgentToolError {
            if case .missingForkedTranscript = error {
                // Expected error.
            } else {
                Issue.record("Unexpected sub agent tool error: \(error)")
            }
        }
    }

    private func decodeRequest(from value: JSONValue) throws -> SubAgentToolRequest {
        let data = try JSONEncoder().encode(value)
        return try JSONDecoder().decode(SubAgentToolRequest.self, from: data)
    }
}
