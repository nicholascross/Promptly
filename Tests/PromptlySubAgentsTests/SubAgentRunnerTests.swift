import Foundation
@testable import PromptlySubAgents
@testable import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import Testing

struct SubAgentRunnerTests {
    @Test
    func filtersDisallowedToolNamesAndKeepsRequiredSubAgentTools() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Tooling Agent",
            description: "Test tool filtering.",
            systemPrompt: "Use tools carefully."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("tooling.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let emptySchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [:],
            description: nil
        )

        let shellCommandConfig = ShellCommandConfig(shellCommands: [
            ShellCommandConfigEntry(
                name: "EchoTool",
                description: "Echo tool for testing.",
                executable: "/usr/bin/true",
                echoOutput: nil,
                truncateOutput: nil,
                argumentTemplate: [["--version"]],
                exclusiveArgumentTemplate: nil,
                optIn: nil,
                parameters: emptySchema
            ),
            ShellCommandConfigEntry(
                name: "SubAgent-fake",
                description: "Disallowed tool.",
                executable: "/usr/bin/true",
                echoOutput: nil,
                truncateOutput: nil,
                argumentTemplate: [["--version"]],
                exclusiveArgumentTemplate: nil,
                optIn: nil,
                parameters: emptySchema
            ),
            ShellCommandConfigEntry(
                name: ReturnToSupervisorTool.toolName,
                description: "Reserved tool.",
                executable: "/usr/bin/true",
                echoOutput: nil,
                truncateOutput: nil,
                argumentTemplate: [["--version"]],
                exclusiveArgumentTemplate: nil,
                optIn: nil,
                parameters: emptySchema
            ),
            ShellCommandConfigEntry(
                name: ReportProgressToSupervisorTool.toolName,
                description: "Reserved tool.",
                executable: "/usr/bin/true",
                echoOutput: nil,
                truncateOutput: nil,
                argumentTemplate: [["--version"]],
                exclusiveArgumentTemplate: nil,
                optIn: nil,
                parameters: emptySchema
            )
        ])

        let localToolsConfigURL = fileManager.currentDirectoryURL.appendingPathComponent("tools.json")
        try fileManager.writeShellCommandConfig(shellCommandConfig, to: localToolsConfigURL)

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let toolBuilder = SubAgentToolBuilder(
            configuration: configuration,
            toolSettings: toolSettings,
            fileManager: fileManager,
            toolOutput: { _ in }
        )

        let tools = try toolBuilder.makeTools(transcriptLogger: nil)
        let toolNames = tools.map { $0.name }

        #expect(toolNames.contains("EchoTool"))
        #expect(!toolNames.contains("SubAgent-fake"))

        let returnToolCount = toolNames.filter { $0 == ReturnToSupervisorTool.toolName }.count
        let progressToolCount = toolNames.filter { $0 == ReportProgressToSupervisorTool.toolName }.count

        #expect(returnToolCount == 1)
        #expect(progressToolCount == 1)
    }

    @Test
    func throwsWhenIncludeFilterMatchesNoTools() throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Tooling Agent",
            description: "Test include validation.",
            systemPrompt: "Use tools carefully."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("tooling.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let emptySchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [:],
            description: nil
        )
        let shellCommandConfig = ShellCommandConfig(shellCommands: [
            ShellCommandConfigEntry(
                name: "EchoTool",
                description: "Echo tool for testing.",
                executable: "/usr/bin/true",
                echoOutput: nil,
                truncateOutput: nil,
                argumentTemplate: [["--version"]],
                exclusiveArgumentTemplate: nil,
                optIn: nil,
                parameters: emptySchema
            )
        ])

        let localToolsConfigURL = fileManager.currentDirectoryURL.appendingPathComponent("tools.json")
        try fileManager.writeShellCommandConfig(shellCommandConfig, to: localToolsConfigURL)

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: ["MissingTool"],
            excludeTools: []
        )

        do {
            let toolBuilder = SubAgentToolBuilder(
                configuration: configuration,
                toolSettings: toolSettings,
                fileManager: fileManager,
                toolOutput: { _ in }
            )
            _ = try toolBuilder.makeTools(transcriptLogger: nil)
            Issue.record("Expected include filter validation error.")
        } catch let error as ToolFactoryError {
            switch error {
            case let .includeFilterMatchesNoTools(filter):
                #expect(filter == "MissingTool")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func returnsFallbackPayloadWhenReturnPayloadIsMissingAndLogsRuntimeStop() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Return Agent",
            description: "Test return enforcement.",
            systemPrompt: "Always return payloads."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("return.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let conversationEntries = [
            PromptMessage(role: .assistant, content: .text("No return tool call"))
        ]
        let stubEndpoint = StubPromptEndpoint(
            result: PromptRunResult(conversationEntries: conversationEntries)
        )

        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: SubAgentSessionState(),
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Summarize the changes",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil
        )

        let payload = try await runner.run(request: request)
        if let payloadObject = objectValue(payload) {
            let result = stringValue(payloadObject["result"])
            #expect(result?.contains("Sub agent did not complete the task.") == true)
            #expect(result?.contains("No return tool call") == true)
            #expect(stringValue(payloadObject["summary"]) == "Sub agent did not complete the task.")
            if let supervisorMessage = objectValue(payloadObject["supervisorMessage"]) {
                #expect(stringValue(supervisorMessage["role"]) == "user")
                #expect(stringValue(supervisorMessage["content"])?.contains("No return tool call") == true)
            } else {
                Issue.record("Expected supervisorMessage to be present.")
            }
        } else {
            Issue.record("Expected missing return payload object.")
        }

        let logFiles = try fileManager.contentsOfDirectory(
            at: runnerLogDirectory(directoryURL: fileManager.currentDirectoryURL),
            includingPropertiesForKeys: nil,
            options: []
        )
        let logFileURL = logFiles.first { $0.pathExtension == "jsonl" }
        if let logFileURL {
            let entries = try fileManager.loadJSONLines(from: logFileURL)
            let runtimeStopEntry = entries.first { entry in
                guard case let .object(object) = entry else { return false }
                return stringValue(object["eventType"]) == "runtime_stop"
            }
            if case let .object(runtimeObject)? = runtimeStopEntry,
               case let .object(dataObject)? = runtimeObject["data"] {
                #expect(stringValue(dataObject["status"]) == "missing_return_payload")
            } else {
                Issue.record("Expected runtime_stop entry.")
            }
        } else {
            Issue.record("Expected log file to be created.")
        }
    }

    @Test
    func retriesWhenReturnPayloadIsMissing() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Return Agent",
            description: "Test return retry behavior.",
            systemPrompt: "Always return payloads."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("return.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let firstEntries = [
            PromptMessage(role: .assistant, content: .text("No return tool call"))
        ]
        let returnPayload: JSONValue = .object([
            "result": .string("All set."),
            "summary": .string("All set.")
        ])
        let secondEntries = [
            PromptMessage(
                role: .assistant,
                content: .empty,
                toolCalls: [
                    PromptToolCall(
                        id: "return-1",
                        name: ReturnToSupervisorTool.toolName,
                        arguments: returnPayload
                    )
                ]
            ),
            PromptMessage(
                role: .tool,
                content: .json(returnPayload),
                toolCallId: "return-1"
            )
        ]
        let stubEndpoint = SequencedPromptEndpoint(results: [
            PromptRunResult(
                conversationEntries: firstEntries,
                resumeToken: "response-1"
            ),
            PromptRunResult(
                conversationEntries: secondEntries,
                resumeToken: "response-2"
            )
        ])

        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: SubAgentSessionState(),
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Summarize the changes",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil
        )

        let payload = try await runner.run(request: request)
        guard case let .object(object) = payload else {
            Issue.record("Expected return payload object.")
            return
        }
        #expect(stringValue(object["result"]) == "All set.")
        #expect(stringValue(object["summary"]) == "All set.")
    }

    @Test
    func addsSupervisorMessageWhenReturnPayloadIsMissing() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Return Agent",
            description: "Test missing return handling.",
            systemPrompt: "Ask questions when you need more information."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("return.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let assistantText = """
        Need more details:
        - What is the target?
        - When is the deadline?
        """
        let conversationEntries = [
            PromptMessage(role: .assistant, content: .text(assistantText))
        ]
        let stubEndpoint = StubPromptEndpoint(
            result: PromptRunResult(conversationEntries: conversationEntries)
        )

        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: SubAgentSessionState(),
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Summarize the changes",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil
        )

        let payload = try await runner.run(request: request)
        guard case let .object(object) = payload else {
            Issue.record("Expected missing return payload object.")
            return
        }
        if case let .bool(needsDecision)? = object["needsSupervisorDecision"] {
            #expect(needsDecision)
        } else {
            Issue.record("Expected needsSupervisorDecision to be true.")
        }

        if case let .string(reason)? = object["decisionReason"] {
            #expect(reason.contains("did not call ReturnToSupervisor"))
        } else {
            Issue.record("Expected decisionReason to be present.")
        }

        if let supervisorMessage = objectValue(object["supervisorMessage"]) {
            #expect(stringValue(supervisorMessage["role"]) == "user")
            let content = stringValue(supervisorMessage["content"])
            #expect(content?.contains("What is the target?") == true)
            #expect(content?.contains("When is the deadline?") == true)
        } else {
            Issue.record("Expected supervisorMessage to be present.")
        }
    }

    @Test
    func storesResumeEntryWhenMoreInformationIsRequested() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Resume Agent",
            description: "Test resume storage.",
            systemPrompt: "Ask for more information when needed."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("resume.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let returnPayload: JSONValue = .object([
            "result": .string("Need more information."),
            "summary": .string("Waiting for more details."),
            "needsMoreInformation": .bool(true),
            "requestedInformation": .array([
                .string("Sample detail")
            ])
        ])
        let conversationEntries = [
            PromptMessage(
                role: .assistant,
                content: .empty,
                toolCalls: [
                    PromptToolCall(
                        id: "return-1",
                        name: ReturnToSupervisorTool.toolName,
                        arguments: returnPayload
                    )
                ]
            ),
            PromptMessage(
                role: .tool,
                content: .json(returnPayload),
                toolCallId: "return-1"
            )
        ]
        let stubEndpoint = StubPromptEndpoint(
            result: PromptRunResult(
                conversationEntries: conversationEntries,
                resumeToken: "response-1"
            )
        )

        let sessionState = SubAgentSessionState()
        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: sessionState,
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Summarize.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil
        )
        let payload = try await runner.run(request: request)

        guard case let .object(object) = payload else {
            Issue.record("Expected resume payload to be an object.")
            return
        }
        guard let resumeId = stringValue(object["resumeId"]) else {
            Issue.record("Expected resume identifier in payload.")
            return
        }
        #expect(!resumeId.isEmpty)

        let storedEntry = await sessionState.entry(for: resumeId)
        #expect(storedEntry?.agentName == "Resume Agent")
        #expect(storedEntry?.resumeToken == "response-1")
        #expect(storedEntry?.conversationEntries.count == conversationEntries.count)
    }

    @Test
    func storesResumeEntryWhenSupervisorDecisionIsNeeded() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Resume Agent",
            description: "Test supervisor decision resume storage.",
            systemPrompt: "Ask for approval when needed."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("resume.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let returnPayload: JSONValue = .object([
            "result": .string("Draft ready."),
            "summary": .string("Awaiting approval."),
            "needsSupervisorDecision": .bool(true),
            "decisionReason": .string("Supervisor approval is required.")
        ])
        let conversationEntries = [
            PromptMessage(
                role: .assistant,
                content: .empty,
                toolCalls: [
                    PromptToolCall(
                        id: "return-1",
                        name: ReturnToSupervisorTool.toolName,
                        arguments: returnPayload
                    )
                ]
            ),
            PromptMessage(
                role: .tool,
                content: .json(returnPayload),
                toolCallId: "return-1"
            )
        ]
        let stubEndpoint = StubPromptEndpoint(
            result: PromptRunResult(
                conversationEntries: conversationEntries,
                resumeToken: "response-2"
            )
        )

        let sessionState = SubAgentSessionState()
        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: sessionState,
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Prepare a draft.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: nil
        )
        let payload = try await runner.run(request: request)

        guard case let .object(object) = payload else {
            Issue.record("Expected resume payload to be an object.")
            return
        }
        guard let resumeId = stringValue(object["resumeId"]) else {
            Issue.record("Expected resume identifier in payload.")
            return
        }
        #expect(!resumeId.isEmpty)

        let storedEntry = await sessionState.entry(for: resumeId)
        #expect(storedEntry?.agentName == "Resume Agent")
        #expect(storedEntry?.resumeToken == "response-2")
        #expect(storedEntry?.conversationEntries.count == conversationEntries.count)
    }

    @Test
    func ignoresNonUuidResumeIdentifier() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Resume Agent",
            description: "Test non-UUID resume identifiers.",
            systemPrompt: "Ask for more information when needed."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("resume.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let returnPayload: JSONValue = .object([
            "result": .string("Need more information."),
            "summary": .string("Waiting for more details."),
            "needsMoreInformation": .bool(true),
            "requestedInformation": .array([
                .string("Sample detail")
            ])
        ])
        let conversationEntries = [
            PromptMessage(
                role: .assistant,
                content: .empty,
                toolCalls: [
                    PromptToolCall(
                        id: "return-1",
                        name: ReturnToSupervisorTool.toolName,
                        arguments: returnPayload
                    )
                ]
            ),
            PromptMessage(
                role: .tool,
                content: .json(returnPayload),
                toolCallId: "return-1"
            )
        ]
        let stubEndpoint = StubPromptEndpoint(
            result: PromptRunResult(
                conversationEntries: conversationEntries,
                resumeToken: nil
            )
        )

        let sessionState = SubAgentSessionState()
        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: sessionState,
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Summarize.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: "self-test"
        )
        let payload = try await runner.run(request: request)

        guard case let .object(object) = payload else {
            Issue.record("Expected resume payload to be an object.")
            return
        }
        guard let resumeId = stringValue(object["resumeId"]) else {
            Issue.record("Expected resume identifier in payload.")
            return
        }
        #expect(!resumeId.isEmpty)
        #expect(resumeId != "self-test")

        let storedEntry = await sessionState.entry(for: resumeId)
        #expect(storedEntry?.agentName == "Resume Agent")
    }

    @Test
    func throwsWhenResumeIdIsInvalid() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Resume Agent",
            description: "Test resume lookup.",
            systemPrompt: "Resume if asked."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("resume.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let stubEndpoint = StubPromptEndpoint(result: PromptRunResult(conversationEntries: []))
        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: SubAgentSessionState(),
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Resume.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: "11111111-1111-1111-1111-111111111111"
        )

        do {
            _ = try await runner.run(request: request)
            Issue.record("Expected invalid resume identifier error.")
        } catch let error as SubAgentToolError {
            switch error {
            case let .invalidResumeId(resumeId):
                #expect(resumeId == "11111111-1111-1111-1111-111111111111")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }

    @Test
    func throwsWhenResponsesResumeTokenIsMissing() async throws {
        let fileManager = InMemoryFileManager()
        let credentialSource = TestCredentialSource(token: "test-token")
        let configurationFileURL = fileManager.currentDirectoryURL.appendingPathComponent("config.json")
        let agentsDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("agents", isDirectory: true)
        try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

        let baseConfiguration = makeBaseConfigurationJSON(model: "base-model")
        try fileManager.writeJSONValue(baseConfiguration, to: configurationFileURL)

        let agentConfiguration = makeAgentConfigurationJSON(
            name: "Resume Agent",
            description: "Test resume token validation.",
            systemPrompt: "Resume if asked."
        )
        let agentFileURL = agentsDirectoryURL.appendingPathComponent("resume.json")
        try fileManager.writeJSONValue(agentConfiguration, to: agentFileURL)

        let loader = SubAgentConfigurationLoader(
            fileManager: fileManager,
            credentialSource: credentialSource
        )
        let configuration = try loader.loadAgentConfiguration(
            configFileURL: configurationFileURL,
            agentConfigurationURL: agentFileURL
        )

        let toolSettings = SubAgentToolSettings(
            toolsFileName: "tools.json",
            includeTools: [],
            excludeTools: []
        )

        let sessionState = SubAgentSessionState()
        _ = await sessionState.storeResumeEntry(
            resumeId: "22222222-2222-2222-2222-222222222222",
            agentName: "Resume Agent",
            conversationEntries: [],
            resumeToken: nil
        )

        let stubEndpoint = StubPromptEndpoint(result: PromptRunResult(conversationEntries: []))
        let runner = SubAgentRunner(
            configuration: configuration,
            toolSettings: toolSettings,
            logDirectoryURL: fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true),
            toolOutput: { _ in },
            fileManager: fileManager,
            sessionState: sessionState,
            modelOverride: nil,
            coordinatorFactory: { _ in stubEndpoint }
        )

        let request = SubAgentToolRequest(
            task: "Resume.",
            contextPack: nil,
            goals: nil,
            constraints: nil,
            resumeId: "22222222-2222-2222-2222-222222222222"
        )

        do {
            _ = try await runner.run(request: request)
            Issue.record("Expected missing resume token error.")
        } catch let error as SubAgentToolError {
            switch error {
            case let .missingResponsesResumeToken(agentName, resumeId):
                #expect(agentName == "Resume Agent")
                #expect(resumeId == "22222222-2222-2222-2222-222222222222")
            default:
                Issue.record("Unexpected error: \(error)")
            }
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}

private struct StubPromptEndpoint: PromptEndpoint {
    let result: PromptRunResult

    func prompt(
        context: PromptRunContext,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult {
        result
    }
}

private actor SequencedPromptEndpoint: PromptEndpoint {
    private let results: [PromptRunResult]
    private var nextIndex = 0

    init(results: [PromptRunResult]) {
        self.results = results
    }

    func prompt(
        context: PromptRunContext,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptRunResult {
        guard !results.isEmpty else {
            return PromptRunResult()
        }
        let result = results[min(nextIndex, results.count - 1)]
        nextIndex += 1
        return result
    }
}

private func runnerLogDirectory(directoryURL: URL) -> URL {
    directoryURL.appendingPathComponent("logs", isDirectory: true)
}
