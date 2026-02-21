import Foundation
import PromptlyKit
import PromptlyKitCommunication
import PromptlyKitTooling
import PromptlyKitUtils
import PromptlySubAgents

public struct SelfTestRunner: Sendable {
    private static let selfTestRequestTimeoutSeconds: TimeInterval = 45
    private static let selfTestResourceTimeoutSeconds: TimeInterval = 120

    public let configurationFileURL: URL
    public let toolsFileName: String
    public let apiOverride: Config.API?
    public let handoffStrategy: SelfTestHandoffStrategy
    private let outputHandler: (@Sendable (String) -> Void)?
    private let fileManager: FileManagerProtocol

    public init(
        configurationFileURL: URL,
        toolsFileName: String = "tools",
        apiOverride: Config.API? = nil,
        handoffStrategy: SelfTestHandoffStrategy = .automatic,
        outputHandler: (@Sendable (String) -> Void)? = nil,
        fileManager: FileManagerProtocol = FileManager.default
    ) {
        self.configurationFileURL = configurationFileURL.standardizedFileURL
        self.toolsFileName = toolsFileName
        self.apiOverride = apiOverride
        self.handoffStrategy = handoffStrategy
        self.outputHandler = outputHandler
        self.fileManager = fileManager
    }

    public static var levels: [SelfTestLevel] {
        SelfTestLevel.allCases
    }

    public func run(level: SelfTestLevel) async -> SelfTestSummary {
        let results: [SelfTestResult]
        switch level {
        case .basic:
            results = await runBasicTests()
        case .tools:
            results = await runToolsTests()
        case .agents:
            results = await runAgentsTests()
        }
        return SelfTestSummary(level: level, results: results)
    }

    private func runBasicTests() async -> [SelfTestResult] {
        var results: [SelfTestResult] = []
        results.append(
            await runTest(name: "Configuration file exists") {
                try ensureConfigurationFileExists()
            }
        )

        let configurationResult = loadConfigurationResult()
        results.append(configurationResult.result)

        guard let configuration = configurationResult.configuration else {
            results.append(
                SelfTestResult(
                    name: "Basic model conversation",
                    status: .failed,
                    details: "Basic tests require a valid configuration."
                )
            )
            return results
        }

        results.append(
            await runTestWithOutput(name: "Basic model conversation") {
                let output = try await verifyBasicConversation(configuration: configuration)
                emit("Basic model conversation output:\n\(output)")
                return SelfTestResult(
                    name: "Basic model conversation",
                    status: .passed,
                    modelOutput: output
                )
            }
        )

        return results
    }

    private func runToolsTests() async -> [SelfTestResult] {
        var results: [SelfTestResult] = []
        let configurationResult = loadConfigurationResult()
        results.append(configurationResult.result)

        guard let configuration = configurationResult.configuration else {
            results.append(
                SelfTestResult(
                    name: "Tool loading and filtering",
                    status: .failed,
                    details: "Tool tests require a valid configuration."
                )
            )
            results.append(
                SelfTestResult(
                    name: "Tool invocation via model",
                    status: .failed,
                    details: "Tool tests require a valid configuration."
                )
            )
            return results
        }

        results.append(
            await runTest(name: "Tool loading and filtering") {
                try await verifyToolLoadingAndFiltering(configuration: configuration)
            }
        )

        results.append(
            await runTestWithOutput(name: "Tool invocation via model") {
                let output = try await verifyToolInvocationWithModel(configuration: configuration)
                if let modelOutput = output.modelOutput {
                    emit("Tool invocation model output:\n\(modelOutput)")
                } else {
                    emit("Tool invocation model output was missing.")
                }
                for toolOutput in output.toolOutputs {
                    let trimmedOutput = toolOutput.output.output.trimmingCharacters(in: .whitespacesAndNewlines)
                    emit("Tool output for \(toolOutput.name):\n\(trimmedOutput)")
                }
                return SelfTestResult(
                    name: "Tool invocation via model",
                    status: .passed,
                    modelOutput: output.modelOutput,
                    toolOutput: output.primaryToolOutput,
                    toolOutputs: output.toolOutputs
                )
            }
        )

        return results
    }

    private func runAgentsTests() async -> [SelfTestResult] {
        var results: [SelfTestResult] = []
        results.append(
            await runTest(name: "Configuration file exists") {
                try ensureConfigurationFileExists()
            }
        )

        let configurationResult = loadConfigurationResult()
        results.append(configurationResult.result)

        guard let configuration = configurationResult.configuration else {
            results.append(
                SelfTestResult(
                    name: "Supervisor uses sub agent tool",
                    status: .failed,
                    details: "Agent tests require a valid configuration."
                )
            )
            results.append(
                SelfTestResult(
                    name: "Supervisor continues incident case",
                    status: .failed,
                    details: "Agent tests require a valid configuration."
                )
            )
            return results
        }

        results.append(
            await runTestWithOutput(name: "Supervisor uses sub agent tool") {
                let result = try await verifySupervisorSubAgentToolInvocation(configuration: configuration)
                if let modelOutput = result.modelOutput {
                    emit("Supervisor output:\n\(modelOutput)")
                } else {
                    emit("Supervisor output was missing.")
                }
                return SelfTestResult(
                    name: "Supervisor uses sub agent tool",
                    status: .passed,
                    modelOutput: result.modelOutput,
                    agentOutput: result.agentOutput
                )
            }
        )

        results.append(
            await runTestWithOutput(name: "Supervisor continues incident case") {
                let result = try await verifySupervisorSubAgentResumeInvocation(configuration: configuration)
                if let modelOutput = result.modelOutput {
                    emit("Supervisor continuation output:\n\(modelOutput)")
                } else {
                    emit("Supervisor continuation output was missing.")
                }
                return SelfTestResult(
                    name: "Supervisor continues incident case",
                    status: .passed,
                    modelOutput: result.modelOutput,
                    agentOutput: result.agentOutput
                )
            }
        )

        return results
    }

    private func loadConfigurationResult() -> (result: SelfTestResult, configuration: Config?) {
        do {
            let configuration = try loadConfiguration()
            return (
                SelfTestResult(name: "Configuration loads", status: .passed),
                configuration
            )
        } catch {
            return (
                SelfTestResult(name: "Configuration loads", status: .failed, details: error.localizedDescription),
                nil
            )
        }
    }

    private func runTest(name: String, action: () async throws -> Void) async -> SelfTestResult {
        do {
            try await action()
            return SelfTestResult(name: name, status: .passed)
        } catch {
            return SelfTestResult(name: name, status: .failed, details: error.localizedDescription)
        }
    }

    private func runTestWithOutput(
        name: String,
        action: () async throws -> SelfTestResult
    ) async -> SelfTestResult {
        do {
            return try await action()
        } catch {
            return SelfTestResult(name: name, status: .failed, details: error.localizedDescription)
        }
    }

    private func emit(_ message: String) {
        outputHandler?(message)
    }

    private func ensureConfigurationFileExists() throws {
        guard fileManager.fileExists(atPath: configurationFileURL.path) else {
            throw SelfTestFailure("Configuration file not found at \(configurationFileURL.path).")
        }
    }

    private func loadConfiguration() throws -> Config {
        try ensureConfigurationFileExists()
        do {
            return try Config.loadConfig(
                url: configurationFileURL,
                credentialSource: SelfTestCredentialSource()
            )
        } catch {
            throw SelfTestFailure("Configuration could not be loaded: \(error)")
        }
    }

    private func verifyBasicConversation(configuration: Config) async throws -> String {
        let coordinator = try PromptRunCoordinator(
            config: configuration,
            apiOverride: apiOverride,
            transport: selfTestTransport()
        )
        let messages = [
            PromptMessage(
                role: .system,
                content: .text(
                    """
                    You are running a self test. Reply with two short sentences.
                    """
                )
            ),
            PromptMessage(
                role: .user,
                content: .text("Confirm the self test ran.")
            )
        ]
        let result = try await coordinator.prompt(
            context: .messages(messages),
            onEvent: { _ in }
        )
        guard let message = latestAssistantMessage(from: result.conversationEntries) else {
            throw SelfTestFailure("Model did not return an assistant message.")
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SelfTestFailure("Model returned an empty assistant message.")
        }
        return trimmed
    }

    private func verifyToolLoadingAndFiltering(configuration: Config) async throws {
        let toolConfiguration = toolLoadingConfiguration()
        try await withTemporaryToolsConfiguration(configuration: toolConfiguration) { toolsConfigurationURL in
            let toolFactory = ToolFactory(
                fileManager: fileManager,
                defaultToolsConfigURL: toolsConfigurationURL,
                localToolsConfigURL: toolsConfigurationURL
            )

            let toolsWithoutInclude = try toolFactory.makeTools(
                config: configuration,
                includeTools: [],
                excludeTools: [],
                toolOutput: { _ in }
            )
            let namesWithoutInclude = Set(toolsWithoutInclude.map { $0.name })
            guard namesWithoutInclude.contains("AlphaTool") else {
                throw SelfTestFailure("Expected AlphaTool to load by default.")
            }
            guard !namesWithoutInclude.contains("BetaTool") else {
                throw SelfTestFailure("Expected BetaTool to remain disabled without explicit inclusion.")
            }

            let toolsWithInclude = try toolFactory.makeTools(
                config: configuration,
                includeTools: ["Beta"],
                excludeTools: [],
                toolOutput: { _ in }
            )
            let namesWithInclude = Set(toolsWithInclude.map { $0.name })
            guard namesWithInclude.contains("BetaTool") else {
                throw SelfTestFailure("Expected BetaTool to load when explicitly included.")
            }

            let toolsWithExclude = try toolFactory.makeTools(
                config: configuration,
                includeTools: ["Beta"],
                excludeTools: ["Alpha"],
                toolOutput: { _ in }
            )
            let namesWithExclude = Set(toolsWithExclude.map { $0.name })
            guard !namesWithExclude.contains("AlphaTool") else {
                throw SelfTestFailure("Expected AlphaTool to be excluded when filtered.")
            }
        }
    }

    private func verifyToolInvocationWithModel(
        configuration: Config
    ) async throws -> (modelOutput: String?, primaryToolOutput: SelfTestToolOutput, toolOutputs: [SelfTestNamedToolOutput]) {
        let toolConfiguration = toolInvocationConfiguration()
        return try await withTemporaryToolsConfiguration(configuration: toolConfiguration) { toolsConfigurationURL in
            let toolFactory = ToolFactory(
                fileManager: fileManager,
                defaultToolsConfigURL: toolsConfigurationURL,
                localToolsConfigURL: toolsConfigurationURL
            )

            let tools = try toolFactory.makeTools(
                config: configuration,
                includeTools: ["ListDirectory", "ShowDateTime"],
                excludeTools: [],
                toolOutput: { _ in }
            )

            guard let listTool = tools.first(where: { $0.name == "ListDirectory" }) else {
                throw SelfTestFailure("ListDirectory tool was not loaded for tool invocation test.")
            }
            guard let dateTool = tools.first(where: { $0.name == "ShowDateTime" }) else {
                throw SelfTestFailure("ShowDateTime tool was not loaded for tool invocation test.")
            }

            let coordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [listTool, dateTool],
                transport: selfTestTransport()
            )
            let messages = [
                PromptMessage(
                    role: .system,
                    content: .text(
                        """
                        You are running a self test.
                        Call the tools named ListDirectory and ShowDateTime exactly once each.
                        Then respond with a brief summary.
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text(
                        "List the current directory and fetch the current date and time using the tools. Include outputs in your reply."
                    )
                )
            ]
            let result = try await coordinator.prompt(
                context: .messages(messages),
                onEvent: { _ in }
            )

            let toolOutputs = try collectToolOutputs(
                names: ["ListDirectory", "ShowDateTime"],
                conversationEntries: result.conversationEntries
            )

            let listOutput = try validatedToolOutput(
                name: "ListDirectory",
                toolOutputs: toolOutputs
            )
            let dateOutput = try validatedToolOutput(
                name: "ShowDateTime",
                toolOutputs: toolOutputs
            )
            guard !listOutput.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SelfTestFailure("ListDirectory tool returned empty output.")
            }
            guard !dateOutput.output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw SelfTestFailure("ShowDateTime tool returned empty output.")
            }

            let modelOutput = latestAssistantMessage(from: result.conversationEntries)
            try validateModelToolSummary(
                modelOutput: modelOutput
            )
            let namedOutputs = [
                SelfTestNamedToolOutput(name: "ListDirectory", output: listOutput),
                SelfTestNamedToolOutput(name: "ShowDateTime", output: dateOutput)
            ]
            return (modelOutput: modelOutput, primaryToolOutput: dateOutput, toolOutputs: namedOutputs)
        }
    }

    private func verifySupervisorSubAgentToolInvocation(
        configuration: Config
    ) async throws -> (modelOutput: String?, agentOutput: JSONValue) {
        return try await withTemporaryConfigurationCopy { temporaryConfigurationFileURL, agentsDirectoryURL in
            let agentName = "Self Test Supervisor Agent"
            let forkedUserEntry = "Self test transcript entry one."
            let forkedAssistantEntry = "Self test transcript entry two."
            let resolvedHandoffStrategy = resolvedHandoffStrategy(
                preferredStrategy: .forkedContext
            )
            emit("Supervisor tool invocation: starting.")
            let toolsConfiguration = try createTemporarySubAgentToolsConfiguration(
                directoryURL: temporaryConfigurationFileURL.deletingLastPathComponent()
            )
            let agentConfigurationURL = try createTemporaryAgentConfiguration(
                agentsDirectoryURL: agentsDirectoryURL,
                agentName: agentName,
                toolsFileName: toolsConfiguration.toolsFileName,
                includeTools: [toolsConfiguration.toolName]
            )

            let toolFactory = SubAgentToolFactory(
                fileManager: fileManager,
                credentialSource: SelfTestCredentialSource()
            )

            emit("Supervisor tool invocation: loading sub agent tools.")
            let tools = try toolFactory.makeTools(
                configurationFileURL: temporaryConfigurationFileURL,
                toolsFileName: toolsConfiguration.toolsFileName,
                modelOverride: nil,
                apiOverride: apiOverride,
                includeTools: [],
                excludeTools: [],
                toolOutput: { _ in }
            )
            emit("Supervisor tool invocation: sub agent tools loaded.")

            let expectedToolName = "SubAgent-\(normalizedIdentifier(from: agentName))"
            guard let agentTool = tools.first(where: { $0.name == expectedToolName }) else {
                throw SelfTestFailure("Expected sub agent tool was not created.")
            }

            let coordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [agentTool],
                transport: selfTestTransport()
            )
            let messages = [
                PromptMessage(
                    role: .system,
                    content: .text(
                        """
                        You are running a self test.
                        Call the tool named \(expectedToolName) exactly once.
                        When you call the tool, set the task to exactly:
                        Provide a short status update.
                        \(handoffInstruction(
                            strategy: resolvedHandoffStrategy,
                            forkedUserEntry: forkedUserEntry,
                            forkedAssistantEntry: forkedAssistantEntry,
                            includeResumeHandle: false
                        ))
                        After the tool returns, respond with a short summary.
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text("Use the sub agent tool now.")
                )
            ]

            emit("Supervisor tool invocation: running supervisor model conversation.")
            let result = try await runSupervisorConversationWithResumeRecovery(
                coordinator: coordinator,
                conversation: messages
            )
            let toolOutputs = try collectToolOutputs(
                names: [expectedToolName],
                conversationEntries: result.conversationEntries
            )
            let toolArguments = try toolCallArguments(
                named: expectedToolName,
                conversationEntries: result.conversationEntries
            )
            emit("Supervisor tool arguments:\n\(formattedJSON(toolArguments))")
            try validateHandoffStrategy(
                arguments: toolArguments,
                expectedStrategy: resolvedHandoffStrategy,
                forkedUserEntry: forkedUserEntry,
                forkedAssistantEntry: forkedAssistantEntry,
                requiresForkedTranscript: resolvedHandoffStrategy == .forkedContext
            )
            if continuationHandle(from: toolArguments) != nil {
                throw SelfTestFailure("Supervisor tool arguments for initial sub agent invocation must omit resumeId.")
            }
            guard let output = toolOutputs[expectedToolName]?.first else {
                throw SelfTestFailure("Missing output for \(expectedToolName).")
            }
            try validateSubAgentPayload(output)
            guard case let .object(object) = output else {
                throw SelfTestFailure("Sub agent payload was not a JSON object.")
            }
            guard case let .string(summary) = object["summary"] else {
                throw SelfTestFailure("Sub agent payload missing summary field.")
            }
            emit("Sub agent summary:\n\(summary)")
            if case let .bool(needsMoreInformation) = object["needsMoreInformation"],
               needsMoreInformation {
                throw SelfTestFailure("Sub agent requested more information during supervisor tool invocation.")
            }
            if let resumeValue = object["resumeId"] {
                throw SelfTestFailure("Sub agent returned a continuation handle when the run was complete: \(resumeValue).")
            }

            guard let modelOutput = latestAssistantMessage(from: result.conversationEntries) else {
                throw SelfTestFailure("Supervisor did not return an assistant message.")
            }
            let trimmedOutput = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOutput.isEmpty else {
                throw SelfTestFailure("Supervisor returned an empty assistant message.")
            }

            try fileManager.removeItem(atPath: agentConfigurationURL.path)
            if fileManager.fileExists(atPath: agentConfigurationURL.path) {
                throw SelfTestFailure("Failed to remove temporary agent configuration file.")
            }

            return (modelOutput: trimmedOutput, agentOutput: output)
        }
    }

    private func verifySupervisorSubAgentResumeInvocation(
        configuration: Config
    ) async throws -> (modelOutput: String?, agentOutput: JSONValue) {
        return try await withTemporaryConfigurationCopy { temporaryConfigurationFileURL, agentsDirectoryURL in
            let agentName = "Self Test Incident Agent"
            let incidentDetailsLine = "Incident Details: Time and location."
            let forkedUserEntry = "Self test incident transcript entry one."
            let forkedAssistantEntry = "Self test incident transcript entry two."
            let resolvedHandoffStrategy = resolvedHandoffStrategy(
                preferredStrategy: .contextPack
            )
            let toolsConfiguration = try createTemporarySubAgentIncidentToolsConfiguration(
                directoryURL: temporaryConfigurationFileURL.deletingLastPathComponent()
            )
            let agentConfigurationURL = try createTemporaryResumeAgentConfiguration(
                agentsDirectoryURL: agentsDirectoryURL,
                agentName: agentName,
                toolsFileName: toolsConfiguration.toolsFileName,
                excludedTools: ["ApplyPatch"]
            )

            let toolFactory = SubAgentToolFactory(
                fileManager: fileManager,
                credentialSource: SelfTestCredentialSource()
            )

            emit("Supervisor incident setup: loading sub agent tools.")
            let tools = try toolFactory.makeTools(
                configurationFileURL: temporaryConfigurationFileURL,
                toolsFileName: toolsConfiguration.toolsFileName,
                modelOverride: nil,
                apiOverride: apiOverride,
                includeTools: [],
                excludeTools: [],
                toolOutput: { _ in }
            )
            emit("Supervisor incident setup: sub agent tools loaded.")

            let expectedToolName = "SubAgent-\(normalizedIdentifier(from: agentName))"
            guard let agentTool = tools.first(where: { $0.name == expectedToolName }) else {
                throw SelfTestFailure("Expected sub agent tool was not created.")
            }

            emit("Supervisor incident step 1: requesting missing details.")
            let firstCoordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [agentTool],
                transport: selfTestTransport()
            )
            let firstMessages = [
                PromptMessage(
                    role: .system,
                    content: .text(
                        """
                        You are running a self test.
                        Call the tool named \(expectedToolName) exactly once.
                        When you call the tool, set the task to exactly:
                        Start the incident intake. Missing time and location.
                        \(handoffInstruction(
                            strategy: resolvedHandoffStrategy,
                            forkedUserEntry: forkedUserEntry,
                            forkedAssistantEntry: forkedAssistantEntry,
                            includeResumeHandle: false
                        ))
                        After the tool returns, respond briefly.
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text("Start the incident intake.")
                )
            ]
            let firstResult = try await runSupervisorConversationWithResumeRecovery(
                coordinator: firstCoordinator,
                conversation: firstMessages
            )
            if let firstOutput = latestAssistantMessage(from: firstResult.conversationEntries) {
                let trimmedOutput = firstOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedOutput.isEmpty {
                    emit("Supervisor incident step 1 output:\n\(trimmedOutput)")
                }
            }
            let firstToolOutputs = try collectToolOutputs(
                names: [expectedToolName],
                conversationEntries: firstResult.conversationEntries
            )
            let firstArguments = try toolCallArguments(
                named: expectedToolName,
                conversationEntries: firstResult.conversationEntries
            )
            emit("Supervisor incident step 1 tool arguments:\n\(formattedJSON(firstArguments))")
            try validateHandoffStrategy(
                arguments: firstArguments,
                expectedStrategy: resolvedHandoffStrategy,
                forkedUserEntry: forkedUserEntry,
                forkedAssistantEntry: forkedAssistantEntry,
                requiresForkedTranscript: resolvedHandoffStrategy == .forkedContext
            )
            if continuationHandle(from: firstArguments) != nil {
                throw SelfTestFailure("Supervisor incident step 1 tool arguments must omit resumeId.")
            }
            guard let firstOutput = firstToolOutputs[expectedToolName]?.first else {
                throw SelfTestFailure("Missing output for \(expectedToolName).")
            }
            let resumeIdentifier = try validateResumeRequestPayload(
                payload: firstOutput
            )
            if case let .object(firstObject) = firstOutput,
               case let .string(firstSummary) = firstObject["summary"] {
                emit("Sub agent summary (step 1):\n\(firstSummary)")
            }
            emit("Case handle: \(resumeIdentifier)")

            emit("Supervisor incident step 2: providing details.")
            let secondCoordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [agentTool],
                transport: selfTestTransport()
            )
            let secondMessages = [
                PromptMessage(
                    role: .system,
                    content: .text(
                        """
                        You are completing the incident intake.
                        Call the tool named \(expectedToolName) exactly once.
                        When you call the tool, set the task to exactly:
                        Continue the incident intake and complete it.
                        \(incidentDetailsLine)
                        The task must include the incident details line on its own line.
                        \(handoffInstruction(
                            strategy: resolvedHandoffStrategy,
                            forkedUserEntry: forkedUserEntry,
                            forkedAssistantEntry: forkedAssistantEntry,
                            includeResumeHandle: true
                        ))
                        Set the continuation handle field named resumeId to: \(resumeIdentifier).
                        After the tool returns, respond with a short summary.
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text(
                        """
                        Continue the incident intake.
                        \(incidentDetailsLine)
                        """
                    )
                )
            ]
            let secondResult = try await runSupervisorConversationWithResumeRecovery(
                coordinator: secondCoordinator,
                conversation: secondMessages
            )
            let secondToolOutputs = try collectToolOutputs(
                names: [expectedToolName],
                conversationEntries: secondResult.conversationEntries
            )
            guard let secondOutput = secondToolOutputs[expectedToolName]?.first else {
                throw SelfTestFailure("Missing output for \(expectedToolName).")
            }
            let secondArguments = try toolCallArguments(
                named: expectedToolName,
                conversationEntries: secondResult.conversationEntries
            )
            emit("Supervisor incident step 2 tool arguments:\n\(formattedJSON(secondArguments))")
            let requiresForkedTranscript = resolvedHandoffStrategy == .forkedContext
            try validateHandoffStrategy(
                arguments: secondArguments,
                expectedStrategy: resolvedHandoffStrategy,
                forkedUserEntry: forkedUserEntry,
                forkedAssistantEntry: forkedAssistantEntry,
                requiresForkedTranscript: requiresForkedTranscript
            )
            guard continuationHandle(from: secondArguments) == resumeIdentifier else {
                throw SelfTestFailure("Supervisor tool arguments did not include the continuation handle.")
            }

            try validateResumeCompletionPayload(
                payload: secondOutput
            )
            guard case let .object(object) = secondOutput else {
                throw SelfTestFailure("Sub agent payload was not a JSON object.")
            }
            guard case let .string(summary) = object["summary"] else {
                throw SelfTestFailure("Sub agent payload missing summary field.")
            }
            emit("Sub agent summary:\n\(summary)")

            guard let modelOutput = latestAssistantMessage(from: secondResult.conversationEntries) else {
                throw SelfTestFailure("Supervisor did not return an assistant message.")
            }
            let trimmedOutput = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOutput.isEmpty else {
                throw SelfTestFailure("Supervisor returned an empty assistant message.")
            }

            try fileManager.removeItem(atPath: agentConfigurationURL.path)
            if fileManager.fileExists(atPath: agentConfigurationURL.path) {
                throw SelfTestFailure("Failed to remove temporary agent configuration file.")
            }

            return (modelOutput: trimmedOutput, agentOutput: secondOutput)
        }
    }

    private func runSupervisorConversationWithResumeRecovery(
        coordinator: PromptRunCoordinator,
        conversation: [PromptMessage]
    ) async throws -> SubAgentSupervisorRunCycle {
        let supervisorRunner = SubAgentSupervisorRunner()
        do {
            return try await supervisorRunner.run(
                conversation: conversation,
                runCycle: { cycleConversation in
                    let cycleResult = try await coordinator.prompt(
                        context: .messages(cycleConversation),
                        onEvent: { _ in }
                    )
                    return SubAgentSupervisorRunCycle(
                        updatedConversation: cycleConversation + cycleResult.conversationEntries,
                        conversationEntries: cycleResult.conversationEntries
                    )
                }
            )
        } catch let error as SubAgentSupervisorRunnerError {
            throw SelfTestFailure(error.localizedDescription)
        } catch {
            throw error
        }
    }

    private func selfTestTransport() -> any NetworkTransport {
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.waitsForConnectivity = false
        sessionConfiguration.timeoutIntervalForRequest = Self.selfTestRequestTimeoutSeconds
        sessionConfiguration.timeoutIntervalForResource = Self.selfTestResourceTimeoutSeconds
        let session = URLSession(configuration: sessionConfiguration)
        return URLSessionNetworkTransport(session: session)
    }

    private func createTemporaryAgentConfiguration(
        agentsDirectoryURL: URL,
        agentName: String,
        toolsFileName: String,
        includeTools: [String]
    ) throws -> URL {
        let toolConfiguration: [String: JSONValue] = [
            "toolsFileName": .string(toolsFileName),
            "include": .array(includeTools.map { .string($0) })
        ]
        let agentDefinition: [String: JSONValue] = [
            "name": .string(agentName),
            "description": .string("Temporary agent used by self tests."),
            "systemPrompt": .string(
                """
                Complete the task and call ReturnToSupervisor exactly once with result and summary fields.
                """
            ),
            "tools": .object(toolConfiguration)
        ]
        let document: JSONValue = .object([
            "agent": .object(agentDefinition)
        ])

        let fileName = "self-test-agent.json"
        let agentConfigurationURL = agentsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let data = try JSONEncoder().encode(document)
        try fileManager.writeData(data, to: agentConfigurationURL)
        return agentConfigurationURL
    }

    private func createTemporaryResumeAgentConfiguration(
        agentsDirectoryURL: URL,
        agentName: String,
        toolsFileName: String,
        excludedTools: [String]
    ) throws -> URL {
        let toolConfiguration: [String: JSONValue] = [
            "toolsFileName": .string(toolsFileName),
            "exclude": .array(excludedTools.map { .string($0) })
        ]
        let systemPrompt = """
        You are running a self test for an incident intake workflow.
        If the user message does not include a line that begins with "Incident Details:", call ReturnToSupervisor with result and summary, set needsMoreInformation to true, and include at least one requestedInformation entry.
        Do not complete the task in that case.
        If the user message includes a line that begins with "Incident Details:", complete the task and call ReturnToSupervisor with result and summary.
        Do not set needsMoreInformation in the completion response, and do not include a continuation handle when completing.
        """
        let agentDefinition: [String: JSONValue] = [
            "name": .string(agentName),
            "description": .string("Temporary agent used by self tests."),
            "systemPrompt": .string(systemPrompt),
            "tools": .object(toolConfiguration)
        ]
        let document: JSONValue = .object([
            "agent": .object(agentDefinition)
        ])

        let fileName = "self-test-incident-agent.json"
        let agentConfigurationURL = agentsDirectoryURL.appendingPathComponent(fileName, isDirectory: false)
        let data = try JSONEncoder().encode(document)
        try fileManager.writeData(data, to: agentConfigurationURL)
        return agentConfigurationURL
    }

    private func createTemporarySubAgentToolsConfiguration(
        directoryURL: URL
    ) throws -> (toolsFileName: String, toolsConfigURL: URL, toolName: String) {
        let toolsFileName = "self-test-tools"
        let toolsConfigURL = directoryURL.appendingPathComponent("\(toolsFileName).json")
        let configuration = subAgentToolConfiguration()
        let data = try JSONEncoder().encode(configuration)
        try fileManager.writeData(data, to: toolsConfigURL)
        return (toolsFileName: toolsConfigURL.path, toolsConfigURL: toolsConfigURL, toolName: "SelfTestListDirectory")
    }

    private func createTemporarySubAgentIncidentToolsConfiguration(
        directoryURL: URL
    ) throws -> (toolsFileName: String, toolsConfigURL: URL) {
        let toolsFileName = "self-test-incident-tools"
        let toolsConfigURL = directoryURL.appendingPathComponent("\(toolsFileName).json")
        let configuration = ShellCommandConfig(shellCommands: [])
        let data = try JSONEncoder().encode(configuration)
        try fileManager.writeData(data, to: toolsConfigURL)
        return (toolsFileName: toolsConfigURL.path, toolsConfigURL: toolsConfigURL)
    }

    private func validateSubAgentPayload(_ payload: JSONValue) throws {
        guard case let .object(object) = payload else {
            throw SelfTestFailure("Sub agent payload was not a JSON object.")
        }
        guard case let .string(result) = object["result"] else {
            throw SelfTestFailure("Sub agent payload missing result field.")
        }
        guard case let .string(summary) = object["summary"] else {
            throw SelfTestFailure("Sub agent payload missing summary field.")
        }
        if result.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SelfTestFailure("Sub agent payload result was empty.")
        }
        if summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            throw SelfTestFailure("Sub agent payload summary was empty.")
        }
    }

    private func validateResumeRequestPayload(
        payload: JSONValue
    ) throws -> String {
        try validateSubAgentPayload(payload)
        guard case let .object(object) = payload else {
            throw SelfTestFailure("Sub agent payload was not a JSON object.")
        }
        guard case let .bool(needsMoreInformation) = object["needsMoreInformation"] else {
            throw SelfTestFailure("Sub agent payload missing needsMoreInformation.")
        }
        guard needsMoreInformation else {
            throw SelfTestFailure("Sub agent did not request more information.")
        }
        guard case let .string(resumeIdentifierValue) = object["resumeId"],
              let resumeIdentifier = normalizedResumeIdentifier(resumeIdentifierValue)
        else {
            throw SelfTestFailure("Sub agent payload missing valid continuation handle.")
        }
        guard case let .array(requestedInformation) = object["requestedInformation"] else {
            throw SelfTestFailure("Sub agent payload missing requestedInformation.")
        }
        let requestedLines = requestedInformation.compactMap { value -> String? in
            guard case let .string(text) = value else { return nil }
            return text
        }
        guard !requestedLines.isEmpty else {
            throw SelfTestFailure("Sub agent requestedInformation was empty.")
        }
        return resumeIdentifier
    }

    private func validateResumeCompletionPayload(
        payload: JSONValue
    ) throws {
        try validateSubAgentPayload(payload)
        guard case let .object(object) = payload else {
            throw SelfTestFailure("Sub agent payload was not a JSON object.")
        }
        if case let .bool(needsMoreInformation) = object["needsMoreInformation"], needsMoreInformation {
            throw SelfTestFailure("Sub agent requested more information during completion.")
        }
        if let resumeValue = object["resumeId"] {
            throw SelfTestFailure("Sub agent returned a continuation handle when the run was complete: \(resumeValue).")
        }
    }

    private func toolCallArguments(
        named name: String,
        conversationEntries: [PromptMessage]
    ) throws -> JSONValue {
        let arguments = conversationEntries.flatMap { entry -> [JSONValue] in
            guard entry.role == .assistant else { return [] }
            guard let toolCalls = entry.toolCalls else { return [] }
            return toolCalls.filter { $0.name == name }.map { $0.arguments }
        }
        if arguments.isEmpty {
            throw SelfTestFailure("Model did not call the \(name) tool.")
        }
        if arguments.count > 1 {
            throw SelfTestFailure("Model called the \(name) tool more than once.")
        }
        return arguments[0]
    }

    private func formattedJSON(_ value: JSONValue) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value),
              let text = String(data: data, encoding: .utf8) else {
            return value.description
        }
        return text
    }

    private func continuationHandle(from arguments: JSONValue) -> String? {
        guard case let .object(object) = arguments else {
            return nil
        }
        guard let resumeIdentifierValue = stringValue(object["resumeId"]) else {
            return nil
        }
        return normalizedResumeIdentifier(resumeIdentifierValue)
    }

    private func handoffStrategy(from arguments: JSONValue) -> String? {
        guard case let .object(object) = arguments else {
            return nil
        }
        return stringValue(object["handoffStrategy"])
    }

    private func resolvedHandoffStrategy(
        preferredStrategy: SelfTestHandoffStrategy
    ) -> SelfTestHandoffStrategy {
        switch handoffStrategy {
        case .automatic:
            return preferredStrategy
        case .contextPack:
            return .contextPack
        case .forkedContext:
            return .forkedContext
        }
    }

    private func handoffStrategyName(
        _ strategy: SelfTestHandoffStrategy
    ) -> String {
        switch strategy {
        case .automatic:
            return "automatic"
        case .contextPack:
            return "contextPack"
        case .forkedContext:
            return "forkedContext"
        }
    }

    private func handoffInstruction(
        strategy: SelfTestHandoffStrategy,
        forkedUserEntry: String,
        forkedAssistantEntry: String,
        includeResumeHandle: Bool
    ) -> String {
        var lines: [String] = []

        switch strategy {
        case .contextPack:
            if includeResumeHandle {
                lines.append(
                    "Provide only task, constraints, handoffStrategy, and the continuation handle field in the tool arguments."
                )
                lines.append("Set resumeId to the continuation handle value provided by the previous tool output.")
            } else {
                lines.append(
                    "Provide only task, constraints, and handoffStrategy fields in the tool arguments."
                )
                lines.append("Do not include resumeId in this call.")
                lines.append("Do not use placeholder values for resumeId such as omit, none, /dev/null, or <!omit>.")
            }
            lines.append("Set handoffStrategy to contextPack.")
        case .forkedContext:
            if includeResumeHandle {
                lines.append(
                    "Provide only task, constraints, handoffStrategy, forkedTranscript, and the continuation handle field in the tool arguments."
                )
                lines.append("Set resumeId to the continuation handle value provided by the previous tool output.")
            } else {
                lines.append(
                    "Provide only task, constraints, handoffStrategy, and forkedTranscript fields in the tool arguments."
                )
                lines.append("Do not include resumeId in this call.")
                lines.append("Do not use placeholder values for resumeId such as omit, none, /dev/null, or <!omit>.")
            }
            lines.append("Set handoffStrategy to forkedContext.")
            lines.append("Set forkedTranscript to:")
            lines.append("- role: user, content: \"\(forkedUserEntry)\"")
            lines.append("- role: assistant, content: \"\(forkedAssistantEntry)\"")
        case .automatic:
            lines.append("Set handoffStrategy to contextPack.")
        }

        return lines.joined(separator: "\n")
    }

    private func validateHandoffStrategy(
        arguments: JSONValue,
        expectedStrategy: SelfTestHandoffStrategy,
        forkedUserEntry: String,
        forkedAssistantEntry: String,
        requiresForkedTranscript: Bool
    ) throws {
        let expectedStrategyName = handoffStrategyName(expectedStrategy)
        guard handoffStrategy(from: arguments) == expectedStrategyName else {
            throw SelfTestFailure(
                "Supervisor tool arguments did not include \(expectedStrategyName) handoff strategy."
            )
        }

        if expectedStrategy == .contextPack {
            if let forkedTranscript = forkedTranscriptEntries(from: arguments),
               !forkedTranscript.isEmpty {
                throw SelfTestFailure(
                    "Supervisor tool arguments included forkedTranscript with contextPack handoff."
                )
            }
            return
        }

        guard expectedStrategy == .forkedContext else {
            return
        }

        if requiresForkedTranscript {
            guard let forkedTranscript = forkedTranscriptEntries(from: arguments),
                  !forkedTranscript.isEmpty else {
                throw SelfTestFailure("Supervisor tool arguments did not include forkedTranscript entries.")
            }
            guard jsonValueContainsString(arguments, substring: forkedUserEntry),
                  jsonValueContainsString(arguments, substring: forkedAssistantEntry) else {
                throw SelfTestFailure("Supervisor tool arguments did not include expected forked transcript entries.")
            }
        }
    }

    private func forkedTranscriptEntries(from arguments: JSONValue) -> [JSONValue]? {
        guard case let .object(object) = arguments else {
            return nil
        }
        guard case let .array(entries)? = object["forkedTranscript"] else {
            return nil
        }
        return entries
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(text)? = value else {
            return nil
        }
        return text
    }

    private func normalizedResumeIdentifier(_ value: String) -> String? {
        let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedValue.isEmpty else {
            return nil
        }
        guard UUID(uuidString: trimmedValue) != nil else {
            return nil
        }
        return trimmedValue.lowercased()
    }

    private func jsonValueContainsString(_ value: JSONValue, substring: String) -> Bool {
        switch value {
        case let .string(text):
            return text.contains(substring)
        case let .array(items):
            return items.contains { jsonValueContainsString($0, substring: substring) }
        case let .object(object):
            return object.values.contains { jsonValueContainsString($0, substring: substring) }
        case .integer, .number, .bool, .null:
            return false
        }
    }

    private func latestAssistantMessage(from conversationEntries: [PromptMessage]) -> String? {
        for entry in conversationEntries.reversed() {
            guard entry.role == .assistant else { continue }
            if case let .text(message) = entry.content {
                return message
            }
        }
        return nil
    }

    private func parseToolOutput(_ output: JSONValue) throws -> SelfTestToolOutput {
        guard case let .object(object) = output else {
            throw SelfTestFailure("Tool output did not include expected JSON object.")
        }
        guard case let .number(exitCode) = object["exitCode"] else {
            throw SelfTestFailure("Tool output did not include an exitCode value.")
        }
        guard case let .string(outputText) = object["output"] else {
            throw SelfTestFailure("Tool output did not include an output string.")
        }
        return SelfTestToolOutput(exitCode: Int(exitCode), output: outputText)
    }

    private func collectToolOutputs(
        names: [String],
        conversationEntries: [PromptMessage]
    ) throws -> [String: [JSONValue]] {
        var toolCallNamesByIdentifier: [String: String] = [:]
        for entry in conversationEntries {
            guard entry.role == .assistant else { continue }
            guard let toolCalls = entry.toolCalls else { continue }
            for toolCall in toolCalls where names.contains(toolCall.name) {
                if let toolCallIdentifier = toolCall.id {
                    toolCallNamesByIdentifier[toolCallIdentifier] = toolCall.name
                }
            }
        }

        var outputs: [String: [JSONValue]] = [:]
        for entry in conversationEntries {
            guard entry.role == .tool else { continue }
            guard let toolCallIdentifier = entry.toolCallId else { continue }
            guard let name = toolCallNamesByIdentifier[toolCallIdentifier] else { continue }
            if case let .json(output) = entry.content {
                outputs[name, default: []].append(output)
            }
        }

        for name in names {
            let count = outputs[name]?.count ?? 0
            if count == 0 {
                throw SelfTestFailure("Model did not call the \(name) tool.")
            }
            if count > 1 {
                throw SelfTestFailure("Model called the \(name) tool more than once.")
            }
        }

        return outputs
    }

    private func validatedToolOutput(
        name: String,
        toolOutputs: [String: [JSONValue]]
    ) throws -> SelfTestToolOutput {
        guard let output = toolOutputs[name]?.first else {
            throw SelfTestFailure("Missing output for \(name) tool.")
        }
        let parsed = try parseToolOutput(output)
        guard parsed.exitCode == 0 else {
            throw SelfTestFailure("\(name) tool returned a nonzero exit code.")
        }
        return parsed
    }

    private func validateModelToolSummary(
        modelOutput: String?
    ) throws {
        guard let modelOutput else {
            throw SelfTestFailure("Model did not provide a summary after tool execution.")
        }
        let trimmedOutput = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            throw SelfTestFailure("Model summary after tool execution was empty.")
        }
    }

    private func withTemporaryConfigurationCopy<T>(
        action: (URL, URL) async throws -> T
    ) async throws -> T {
        try await withTemporaryDirectory { temporaryDirectoryURL in
            let configurationData = try fileManager.readData(at: configurationFileURL)
            let temporaryConfigurationFileURL = temporaryDirectoryURL.appendingPathComponent("config.json")
            try fileManager.writeData(configurationData, to: temporaryConfigurationFileURL)

            let agentsDirectoryURL = temporaryDirectoryURL.appendingPathComponent("agents", isDirectory: true)
            try fileManager.createDirectory(at: agentsDirectoryURL, withIntermediateDirectories: true, attributes: nil)

            return try await action(temporaryConfigurationFileURL, agentsDirectoryURL)
        }
    }

    private func withTemporaryToolsConfiguration<T>(
        configuration: ShellCommandConfig,
        action: (URL) async throws -> T
    ) async throws -> T {
        try await withTemporaryDirectory { temporaryDirectoryURL in
            let toolsConfigurationURL = temporaryDirectoryURL.appendingPathComponent("tools.json")
            let data = try JSONEncoder().encode(configuration)
            try fileManager.writeData(data, to: toolsConfigurationURL)

            return try await action(toolsConfigurationURL)
        }
    }

    private func withTemporaryDirectory<T>(
        action: (URL) async throws -> T
    ) async throws -> T {
        let baseTemporaryDirectory = URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let temporaryDirectoryURL = baseTemporaryDirectory
            .appendingPathComponent("promptly-self-test-\(UUID().uuidString)", isDirectory: true)
        try fileManager.createDirectory(at: temporaryDirectoryURL, withIntermediateDirectories: true, attributes: nil)
        defer {
            try? fileManager.removeItem(atPath: temporaryDirectoryURL.path)
        }
        return try await action(temporaryDirectoryURL)
    }

    private func toolLoadingConfiguration() -> ShellCommandConfig {
        let emptySchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [:],
            description: nil
        )

        let alphaTool = ShellCommandConfigEntry(
            name: "AlphaTool",
            description: "Tool entry for self tests.",
            executable: "/usr/bin/true",
            echoOutput: nil,
            truncateOutput: nil,
            argumentTemplate: [["--version"]],
            exclusiveArgumentTemplate: nil,
            optIn: nil,
            parameters: emptySchema
        )

        let betaTool = ShellCommandConfigEntry(
            name: "BetaTool",
            description: "Opt-in tool entry for self tests.",
            executable: "/usr/bin/true",
            echoOutput: nil,
            truncateOutput: nil,
            argumentTemplate: [["--version"]],
            exclusiveArgumentTemplate: nil,
            optIn: true,
            parameters: emptySchema
        )

        return ShellCommandConfig(shellCommands: [alphaTool, betaTool])
    }

    private func toolInvocationConfiguration() -> ShellCommandConfig {
        let emptySchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [:],
            description: nil
        )

        let listDirectoryTool = ShellCommandConfigEntry(
            name: "ListDirectory",
            description: "List entries in the current working directory.",
            executable: "/bin/ls",
            echoOutput: nil,
            truncateOutput: nil,
            argumentTemplate: [["-1"]],
            exclusiveArgumentTemplate: nil,
            optIn: nil,
            parameters: emptySchema
        )

        let dateTimeTool = ShellCommandConfigEntry(
            name: "ShowDateTime",
            description: "Return the current date and time.",
            executable: "/bin/date",
            echoOutput: nil,
            truncateOutput: nil,
            argumentTemplate: [["+%Y-%m-%d %H:%M:%S %z"]],
            exclusiveArgumentTemplate: nil,
            optIn: nil,
            parameters: emptySchema
        )

        return ShellCommandConfig(shellCommands: [listDirectoryTool, dateTimeTool])
    }

    private func subAgentToolConfiguration() -> ShellCommandConfig {
        let emptySchema = JSONSchema.object(
            requiredProperties: [:],
            optionalProperties: [:],
            description: nil
        )

        let listDirectoryTool = ShellCommandConfigEntry(
            name: "SelfTestListDirectory",
            description: "List entries in the current working directory.",
            executable: "/bin/ls",
            echoOutput: nil,
            truncateOutput: nil,
            argumentTemplate: [["-1"]],
            exclusiveArgumentTemplate: nil,
            optIn: nil,
            parameters: emptySchema
        )

        return ShellCommandConfig(shellCommands: [listDirectoryTool])
    }

    private func normalizedIdentifier(from name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowered = trimmed.lowercased()
        let allowedCharacters = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")

        var normalized = ""
        var previousWasSeparator = false
        for scalar in lowered.unicodeScalars {
            if allowedCharacters.contains(scalar) {
                normalized.unicodeScalars.append(scalar)
                previousWasSeparator = false
            } else if !previousWasSeparator {
                normalized.append("-")
                previousWasSeparator = true
            }
        }

        let trimmedSeparators = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmedSeparators.isEmpty ? "agent" : trimmedSeparators
    }
}

private struct SelfTestFailure: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? {
        message
    }
}
