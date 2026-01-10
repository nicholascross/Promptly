import Foundation
@testable import PromptlyKit
import PromptlyKitUtils
@testable import PromptlySubAgents
import Testing

struct SubAgentHandoffStrategyTests {
    @Test
    func decodesForkedTranscriptRequestFields() throws {
        let arguments: JSONValue = .object([
            "task": .string("Summarize the conversation."),
            "handoffStrategy": .string("forkedContext"),
            "forkedTranscript": .array([
                .object([
                    "role": .string("user"),
                    "content": .string("Provide a summary.")
                ]),
                .object([
                    "role": .string("assistant"),
                    "content": .string("Here is a draft summary.")
                ])
            ])
        ])

        let request = try arguments.decoded(SubAgentToolRequest.self)

        switch request.handoff {
        case let .forkedContext(entries):
            #expect(entries.count == 2)
            #expect(entries.first?.role == "user")
        case .contextPack:
            Issue.record("Expected forkedContext handoff.")
        }
    }

    @Test
    func forkedContextRequiresTranscript() {
        do {
            let arguments: JSONValue = .object([
                "task": .string("Summarize the conversation."),
                "handoffStrategy": .string("forkedContext")
            ])
            _ = try arguments.decoded(SubAgentToolRequest.self)
            Issue.record("Expected missing forked transcript decode error.")
        } catch let error as SubAgentToolError {
            switch error {
            case .missingForkedTranscript:
                break
            default:
                Issue.record("Expected missingForkedTranscript error.")
            }
        } catch {
            Issue.record("Expected SubAgentToolError for missing forked transcript.")
        }
    }

    @Test
    func forkedContextRejectsEmptyTranscript() {
        let request = SubAgentToolRequest(
            task: "Summarize the conversation.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil,
            handoff: .forkedContext([])
        )

        do {
            _ = try SubAgentForkedContextHandoffStrategy().makeHandoffMessages(
                request: request,
                systemMessage: PromptMessage(role: .system, content: .text("System")),
                userMessage: PromptMessage(role: .user, content: .text("Task")),
                resumeEntry: nil
            )
            Issue.record("Expected empty forked transcript error.")
        } catch let error as SubAgentToolError {
            switch error {
            case .emptyForkedTranscript:
                break
            default:
                Issue.record("Expected emptyForkedTranscript error.")
            }
        } catch {
            Issue.record("Expected SubAgentToolError for empty forked transcript.")
        }
    }

    @Test
    func forkedContextRejectsInvalidRoles() {
        let request = SubAgentToolRequest(
            task: "Summarize the conversation.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil,
            handoff: .forkedContext([
                SubAgentForkedTranscriptEntry(
                    role: "tool",
                    content: "Tool output should be excluded."
                )
            ])
        )

        do {
            _ = try SubAgentForkedContextHandoffStrategy().makeHandoffMessages(
                request: request,
                systemMessage: PromptMessage(role: .system, content: .text("System")),
                userMessage: PromptMessage(role: .user, content: .text("Task")),
                resumeEntry: nil
            )
            Issue.record("Expected invalid role error.")
        } catch let error as SubAgentToolError {
            switch error {
            case let .invalidForkedTranscriptRole(index, role):
                #expect(index == 0)
                #expect(role == "tool")
            default:
                Issue.record("Expected invalidForkedTranscriptRole error.")
            }
        } catch {
            Issue.record("Expected SubAgentToolError for invalid role.")
        }
    }

    @Test
    func forkedContextRejectsEmptyContent() {
        let request = SubAgentToolRequest(
            task: "Summarize the conversation.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil,
            handoff: .forkedContext([
                SubAgentForkedTranscriptEntry(
                    role: "user",
                    content: "   "
                )
            ])
        )

        do {
            _ = try SubAgentForkedContextHandoffStrategy().makeHandoffMessages(
                request: request,
                systemMessage: PromptMessage(role: .system, content: .text("System")),
                userMessage: PromptMessage(role: .user, content: .text("Task")),
                resumeEntry: nil
            )
            Issue.record("Expected empty content error.")
        } catch let error as SubAgentToolError {
            switch error {
            case let .emptyForkedTranscriptContent(index):
                #expect(index == 0)
            default:
                Issue.record("Expected emptyForkedTranscriptContent error.")
            }
        } catch {
            Issue.record("Expected SubAgentToolError for empty content.")
        }
    }

    @Test
    func forkedContextRejectsOversizedTranscript() {
        let entries = (0..<41).map { _ in
            SubAgentForkedTranscriptEntry(
                role: "user",
                content: "Message"
            )
        }
        let request = SubAgentToolRequest(
            task: "Summarize the conversation.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil,
            handoff: .forkedContext(entries)
        )

        do {
            _ = try SubAgentForkedContextHandoffStrategy().makeHandoffMessages(
                request: request,
                systemMessage: PromptMessage(role: .system, content: .text("System")),
                userMessage: PromptMessage(role: .user, content: .text("Task")),
                resumeEntry: nil
            )
            Issue.record("Expected size limit error.")
        } catch let error as SubAgentToolError {
            switch error {
            case let .forkedTranscriptTooLarge(maximumMessageCount, maximumCharacterCount):
                #expect(maximumMessageCount == 40)
                #expect(maximumCharacterCount == 20000)
            default:
                Issue.record("Expected forkedTranscriptTooLarge error.")
            }
        } catch {
            Issue.record("Expected SubAgentToolError for size limit.")
        }
    }

    @Test
    func forkedContextHandoffPlanIncludesBoundaryAndTranscript() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Forked Agent",
            description: "Test forked transcript handoff.",
            systemPrompt: "Follow instructions."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("forked.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let assembler = SubAgentPromptAssembler(
            configuration: configuration,
            sessionState: SubAgentSessionState()
        )
        let request = SubAgentToolRequest(
            task: "Summarize the conversation.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil,
            handoff: .forkedContext([
                SubAgentForkedTranscriptEntry(role: "user", content: "First request."),
                SubAgentForkedTranscriptEntry(role: "assistant", content: "First response.")
            ])
        )

        let plan = try assembler.makeHandoffPlan(
            for: request,
            systemMessage: assembler.makeSystemMessage(),
            userMessage: assembler.makeUserMessage(for: request),
            resumeEntry: nil
        )

        #expect(plan.handoffMessages.count == 5)
        #expect(plan.handoffMessages.first?.role == PromptRole.system)
        #expect(plan.handoffMessages[2].role == PromptRole.user)
        #expect(plan.handoffMessages[3].role == PromptRole.assistant)
        #expect(plan.handoffMessages.last?.role == PromptRole.user)

        if case let .text(boundaryText) = plan.handoffMessages[1].content {
            #expect(boundaryText.contains("Forked transcript"))
            #expect(boundaryText.contains("read only"))
        } else {
            Issue.record("Expected boundary marker text message.")
        }
    }
}
