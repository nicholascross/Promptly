import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import PromptlySubAgents

public struct SelfTestRunner: Sendable {
    public let configurationFileURL: URL
    public let toolsFileName: String
    public let apiOverride: Config.API?
    private let outputHandler: (@Sendable (String) -> Void)?
    private let fileManager: FileManagerProtocol

    public init(
        configurationFileURL: URL,
        toolsFileName: String = "tools",
        apiOverride: Config.API? = nil,
        outputHandler: (@Sendable (String) -> Void)? = nil,
        fileManager: FileManagerProtocol = FileManager.default
    ) {
        self.configurationFileURL = configurationFileURL.standardizedFileURL
        self.toolsFileName = toolsFileName
        self.apiOverride = apiOverride
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
                credentialSource: SystemCredentialSource()
            )
        } catch {
            throw SelfTestFailure("Configuration could not be loaded: \(error)")
        }
    }

    private func verifyBasicConversation(configuration: Config) async throws -> String {
        let token = UUID().uuidString
        let seedWord = randomSeedWord()
        let coordinator = try PromptRunCoordinator(
            config: configuration,
            apiOverride: apiOverride
        )
        let messages = [
            PromptMessage(
                role: .system,
                content: .text(
                    """
                    You are running a self test. Reply with two short sentences.
                    The first sentence must start with the word "\(seedWord)".
                    Include the exact token: \(token).
                    """
                )
            ),
            PromptMessage(
                role: .user,
                content: .text("Confirm the self test ran, start with the required word, and include the token.")
            )
        ]
        let result = try await coordinator.run(messages: messages, onEvent: { _ in })
        guard let message = latestAssistantMessage(from: result.promptTranscript) else {
            throw SelfTestFailure("Model did not return an assistant message.")
        }
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw SelfTestFailure("Model returned an empty assistant message.")
        }
        guard trimmed.contains(token) else {
            throw SelfTestFailure("Model response did not include the expected token.")
        }
        guard startsWithSeedWord(trimmed, seedWord: seedWord) else {
            throw SelfTestFailure("Model response did not start with the expected word.")
        }
        if trimmed.count < 20 {
            throw SelfTestFailure("Model response was too short to confirm a real conversation.")
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
                tools: [listTool, dateTool]
            )
            let messages = [
                PromptMessage(
                    role: .system,
                    content: .text(
                        """
                        You are running a self test.
                        Call the tools named ListDirectory and ShowDateTime exactly once each.
                        Then respond with a brief summary that includes the date/time output and one file name from the directory listing.
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
            let result = try await coordinator.run(messages: messages, onEvent: { _ in })

            let toolOutputs = try collectToolOutputs(
                names: ["ListDirectory", "ShowDateTime"],
                transcript: result.promptTranscript
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

            let modelOutput = latestAssistantMessage(from: result.promptTranscript)
            try validateModelToolSummary(
                modelOutput: modelOutput,
                dateOutput: dateOutput.output,
                listOutput: listOutput.output
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
            let token = UUID().uuidString
            let tokenLine = "Supervisor Output Token: \(token)"
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
                credentialSource: SystemCredentialSource()
            )
            let toolsConfigurationURL = toolsConfiguration.toolsConfigURL
            let subAgentSessionState = SubAgentSessionState()

            let tools = try toolFactory.makeTools(
                configurationFileURL: temporaryConfigurationFileURL,
                defaultToolsConfigURL: toolsConfigurationURL,
                localToolsConfigURL: toolsConfigurationURL,
                sessionState: subAgentSessionState,
                apiOverride: apiOverride,
                includeTools: [],
                excludeTools: [],
                toolOutput: { _ in }
            )

            let expectedToolName = "SubAgent-\(normalizedIdentifier(from: agentName))"
            guard let agentTool = tools.first(where: { $0.name == expectedToolName }) else {
                throw SelfTestFailure("Expected sub agent tool was not created.")
            }

            let coordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [agentTool]
            )
            let messages = [
                PromptMessage(
                    role: .system,
                    content: .text(
                        """
                        You are running a self test.
                        Call the tool named \(expectedToolName) exactly once.
                        When you call the tool, set the task to exactly:
                        Return a summary that includes the line "\(tokenLine)".
                        Provide only task and constraints fields in the tool arguments.
                        After the tool returns, respond with a short summary that includes the line "\(tokenLine)".
                        Include the sub agent summary exactly as returned, prefixed with "Sub agent summary:".
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text("Use the sub agent tool now.")
                )
            ]

            let result = try await coordinator.run(messages: messages, onEvent: { _ in })
            let toolOutputs = try collectToolOutputs(
                names: [expectedToolName],
                transcript: result.promptTranscript
            )
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
            guard summary.contains(tokenLine) else {
                throw SelfTestFailure("Sub agent summary did not include the supervisor token line.")
            }

            guard let modelOutput = latestAssistantMessage(from: result.promptTranscript) else {
                throw SelfTestFailure("Supervisor did not return an assistant message.")
            }
            let trimmedOutput = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOutput.isEmpty else {
                throw SelfTestFailure("Supervisor returned an empty assistant message.")
            }
            guard trimmedOutput.contains(tokenLine) else {
                throw SelfTestFailure("Supervisor summary did not include the token line.")
            }
            let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedOutput.contains(trimmedSummary) else {
                throw SelfTestFailure("Supervisor summary did not include the sub agent summary.")
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
            let intakeAnchorToken = UUID().uuidString
            let intakeAnchorLine = "Intake Anchor: \(intakeAnchorToken)"
            let incidentTimeToken = UUID().uuidString
            let incidentLocationToken = UUID().uuidString
            let incidentDetailsLine = "Incident Details: \(incidentTimeToken) at \(incidentLocationToken)"
            let missingIncidentDetailsLine = "Incident Details Needed: time and location."
            let toolsConfiguration = try createTemporarySubAgentIncidentToolsConfiguration(
                directoryURL: temporaryConfigurationFileURL.deletingLastPathComponent()
            )
            let agentConfigurationURL = try createTemporaryResumeAgentConfiguration(
                agentsDirectoryURL: agentsDirectoryURL,
                agentName: agentName,
                toolsFileName: toolsConfiguration.toolsFileName,
                missingIncidentDetailsLine: missingIncidentDetailsLine,
                intakeAnchorLine: intakeAnchorLine,
                excludedTools: ["ApplyPatch"]
            )

            let toolFactory = SubAgentToolFactory(
                fileManager: fileManager,
                credentialSource: SystemCredentialSource()
            )
            let toolsConfigurationURL = toolsConfiguration.toolsConfigURL
            let subAgentSessionState = SubAgentSessionState()

            let tools = try toolFactory.makeTools(
                configurationFileURL: temporaryConfigurationFileURL,
                defaultToolsConfigURL: toolsConfigurationURL,
                localToolsConfigURL: toolsConfigurationURL,
                sessionState: subAgentSessionState,
                apiOverride: apiOverride,
                includeTools: [],
                excludeTools: [],
                toolOutput: { _ in }
            )

            let expectedToolName = "SubAgent-\(normalizedIdentifier(from: agentName))"
            guard let agentTool = tools.first(where: { $0.name == expectedToolName }) else {
                throw SelfTestFailure("Expected sub agent tool was not created.")
            }

            emit("Supervisor incident step 1: requesting missing details.")
            let firstCoordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [agentTool]
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
                        \(intakeAnchorLine)
                        Provide only task and constraints fields in the tool arguments.
                        After the tool returns, respond briefly and include the line "\(intakeAnchorLine)".
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text("Start the incident intake.")
                )
            ]
            let firstResult = try await firstCoordinator.run(messages: firstMessages, onEvent: { _ in })
            if let firstOutput = latestAssistantMessage(from: firstResult.promptTranscript) {
                let trimmedOutput = firstOutput.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedOutput.isEmpty {
                    emit("Supervisor incident step 1 output:\n\(trimmedOutput)")
                }
            }
            let firstToolOutputs = try collectToolOutputs(
                names: [expectedToolName],
                transcript: firstResult.promptTranscript
            )
            guard let firstOutput = firstToolOutputs[expectedToolName]?.first else {
                throw SelfTestFailure("Missing output for \(expectedToolName).")
            }
            let requestOutcome = try validateResumeRequestPayload(
                payload: firstOutput,
                missingIncidentDetailsLine: missingIncidentDetailsLine,
                intakeAnchorLine: intakeAnchorLine
            )
            if case let .object(firstObject) = firstOutput,
               case let .string(firstSummary) = firstObject["summary"] {
                emit("Sub agent summary (step 1):\n\(firstSummary)")
            }
            emit("Case note: \(requestOutcome.caseNoteLine)")
            emit("Case handle: \(requestOutcome.resumeIdentifier)")

            emit("Supervisor incident step 2: providing details.")
            let secondCoordinator = try PromptRunCoordinator(
                config: configuration,
                apiOverride: apiOverride,
                tools: [agentTool]
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
                        Provide only task, constraints, and the continuation handle field in the tool arguments.
                        Set the continuation handle field named resumeId to: \(requestOutcome.resumeIdentifier).
                        Do not include the "\(intakeAnchorLine)" line in the tool arguments.
                        After the tool returns, respond with a short summary that includes the line "\(incidentDetailsLine)" and "\(intakeAnchorLine)".
                        Include the case note line from the prior tool response in your summary.
                        Include the sub agent summary exactly as returned, prefixed with "Sub agent summary:".
                        """
                    )
                ),
                PromptMessage(
                    role: .user,
                    content: .text("Continue the incident intake.")
                )
            ]
            let secondResult = try await secondCoordinator.run(messages: secondMessages, onEvent: { _ in })
            let secondToolOutputs = try collectToolOutputs(
                names: [expectedToolName],
                transcript: secondResult.promptTranscript
            )
            guard let secondOutput = secondToolOutputs[expectedToolName]?.first else {
                throw SelfTestFailure("Missing output for \(expectedToolName).")
            }
            let secondArguments = try toolCallArguments(
                named: expectedToolName,
                transcript: secondResult.promptTranscript
            )
            emit("Supervisor incident step 2 tool arguments:\n\(formattedJSON(secondArguments))")
            if jsonValueContainsString(secondArguments, substring: intakeAnchorLine) {
                throw SelfTestFailure("Supervisor tool arguments included the intake anchor line.")
            }
            guard continuationHandle(from: secondArguments) == requestOutcome.resumeIdentifier else {
                throw SelfTestFailure("Supervisor tool arguments did not include the continuation handle.")
            }

            try validateResumeCompletionPayload(
                payload: secondOutput,
                incidentDetailsLine: incidentDetailsLine,
                intakeAnchorLine: intakeAnchorLine,
                caseNoteLine: requestOutcome.caseNoteLine
            )
            guard case let .object(object) = secondOutput else {
                throw SelfTestFailure("Sub agent payload was not a JSON object.")
            }
            guard case let .string(summary) = object["summary"] else {
                throw SelfTestFailure("Sub agent payload missing summary field.")
            }
            emit("Sub agent summary:\n\(summary)")

            guard let modelOutput = latestAssistantMessage(from: secondResult.promptTranscript) else {
                throw SelfTestFailure("Supervisor did not return an assistant message.")
            }
            let trimmedOutput = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedOutput.isEmpty else {
                throw SelfTestFailure("Supervisor returned an empty assistant message.")
            }
            guard trimmedOutput.contains(incidentDetailsLine) else {
                throw SelfTestFailure("Supervisor summary did not include the incident details line.")
            }
            guard trimmedOutput.contains(intakeAnchorLine) else {
                throw SelfTestFailure("Supervisor summary did not include the intake anchor line.")
            }
            guard trimmedOutput.contains(requestOutcome.caseNoteLine) else {
                throw SelfTestFailure("Supervisor summary did not include the case note line.")
            }
            let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmedOutput.contains(trimmedSummary) else {
                throw SelfTestFailure("Supervisor summary did not include the sub agent summary.")
            }

            try fileManager.removeItem(atPath: agentConfigurationURL.path)
            if fileManager.fileExists(atPath: agentConfigurationURL.path) {
                throw SelfTestFailure("Failed to remove temporary agent configuration file.")
            }

            return (modelOutput: trimmedOutput, agentOutput: secondOutput)
        }
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
                If the task includes a line that begins with "Supervisor Output Token:", include that line verbatim in both the result and summary.
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
        missingIncidentDetailsLine: String,
        intakeAnchorLine: String,
        excludedTools: [String]
    ) throws -> URL {
        let toolConfiguration: [String: JSONValue] = [
            "toolsFileName": .string(toolsFileName),
            "exclude": .array(excludedTools.map { .string($0) })
        ]
        let systemPrompt = """
        You are running a self test for an incident intake workflow.
        If the user message does not include a line that begins with "Incident Details:", call ReturnToSupervisor with result and summary, set needsMoreInformation to true, and include the exact line "\(missingIncidentDetailsLine)" in requestedInformation.
        In that case, include a standalone line that begins with "Case Note:" followed by a short identifier you create in the summary.
        Also include the line "\(intakeAnchorLine)" in the summary.
        Do not complete the task in that case.
        If the user message includes a line that begins with "Incident Details:", complete the task and call ReturnToSupervisor with result and summary.
        Include the full "Incident Details:" line verbatim in the summary, along with the earlier "Case Note:" line and the "\(intakeAnchorLine)" line from the initial request.
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
        return (toolsFileName: toolsFileName, toolsConfigURL: toolsConfigURL, toolName: "SelfTestListDirectory")
    }

    private func createTemporarySubAgentIncidentToolsConfiguration(
        directoryURL: URL
    ) throws -> (toolsFileName: String, toolsConfigURL: URL) {
        let toolsFileName = "self-test-incident-tools"
        let toolsConfigURL = directoryURL.appendingPathComponent("\(toolsFileName).json")
        let configuration = ShellCommandConfig(shellCommands: [])
        let data = try JSONEncoder().encode(configuration)
        try fileManager.writeData(data, to: toolsConfigURL)
        return (toolsFileName: toolsFileName, toolsConfigURL: toolsConfigURL)
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
        payload: JSONValue,
        missingIncidentDetailsLine: String,
        intakeAnchorLine: String
    ) throws -> (resumeIdentifier: String, caseNoteLine: String) {
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
        guard case let .string(resumeIdentifier) = object["resumeId"],
              !resumeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw SelfTestFailure("Sub agent payload missing continuation handle.")
        }
        guard case let .array(requestedInformation) = object["requestedInformation"] else {
            throw SelfTestFailure("Sub agent payload missing requestedInformation.")
        }
        let requestedLines = requestedInformation.compactMap { value -> String? in
            guard case let .string(text) = value else { return nil }
            return text
        }
        guard requestedLines.contains(where: { $0.contains(missingIncidentDetailsLine) }) else {
            throw SelfTestFailure("Sub agent did not request the expected incident details.")
        }
        guard case let .string(summary) = object["summary"] else {
            throw SelfTestFailure("Sub agent payload missing summary.")
        }
        guard summary.contains(intakeAnchorLine) else {
            throw SelfTestFailure("Sub agent summary did not include the intake anchor line.")
        }
        let caseNoteLine = try caseNoteLine(from: summary)
        return (resumeIdentifier: resumeIdentifier, caseNoteLine: caseNoteLine)
    }

    private func validateResumeCompletionPayload(
        payload: JSONValue,
        incidentDetailsLine: String,
        intakeAnchorLine: String,
        caseNoteLine: String
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
        guard case let .string(summary) = object["summary"] else {
            throw SelfTestFailure("Sub agent payload missing summary.")
        }
        guard summary.contains(incidentDetailsLine) else {
            throw SelfTestFailure("Sub agent summary did not include the incident details line.")
        }
        guard summary.contains(intakeAnchorLine) else {
            throw SelfTestFailure("Sub agent summary did not include the intake anchor line.")
        }
        guard summary.contains(caseNoteLine) else {
            throw SelfTestFailure("Sub agent summary did not include the case note line.")
        }
    }

    private func caseNoteLine(from summary: String) throws -> String {
        let lines = summary.split(whereSeparator: \.isNewline).map(String.init)
        if let line = lines.first(where: { $0.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("Case Note:") }) {
            return line.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let range = summary.range(of: "Case Note:") {
            let trailing = summary[range.lowerBound...]
            if let endRange = trailing.range(of: "\n") {
                return String(trailing[..<endRange.lowerBound]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
            return String(trailing).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        throw SelfTestFailure("Sub agent summary did not include a case note line.")
    }

    private func toolCallArguments(
        named name: String,
        transcript: [PromptTranscriptEntry]
    ) throws -> JSONValue {
        let arguments = transcript.compactMap { entry -> JSONValue? in
            guard case let .toolCall(_, entryName, entryArguments, _) = entry, entryName == name else {
                return nil
            }
            return entryArguments
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
        return stringValue(object["resumeId"])
    }

    private func stringValue(_ value: JSONValue?) -> String? {
        guard case let .string(text)? = value else {
            return nil
        }
        return text
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

    private func latestAssistantMessage(from transcript: [PromptTranscriptEntry]) -> String? {
        for entry in transcript.reversed() {
            if case let .assistant(message) = entry {
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
        transcript: [PromptTranscriptEntry]
    ) throws -> [String: [JSONValue]] {
        var outputs: [String: [JSONValue]] = [:]
        for entry in transcript {
            guard case let .toolCall(_, name, _, output) = entry else { continue }
            guard let output else { continue }
            if names.contains(name) {
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
        modelOutput: String?,
        dateOutput: String,
        listOutput: String
    ) throws {
        guard let modelOutput else {
            throw SelfTestFailure("Model did not provide a summary after tool execution.")
        }
        let trimmedOutput = modelOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedOutput.isEmpty else {
            throw SelfTestFailure("Model summary after tool execution was empty.")
        }

        let trimmedDate = dateOutput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedOutput.contains(trimmedDate) else {
            throw SelfTestFailure("Model summary did not include the date/time output.")
        }

        let listLines = listOutput
            .split(whereSeparator: { character in
                character.unicodeScalars.allSatisfy { scalar in
                    CharacterSet.whitespacesAndNewlines.contains(scalar)
                }
            })
            .map(String.init)
        guard let firstItem = listLines.first, !firstItem.isEmpty else {
            throw SelfTestFailure("Directory listing did not include any entries.")
        }
        guard trimmedOutput.contains(firstItem) else {
            throw SelfTestFailure("Model summary did not include a file name from the directory listing.")
        }
    }

    private func randomSeedWord() -> String {
        let words = [
            "Bright",
            "Calm",
            "Crisp",
            "Lively",
            "Quiet",
            "Steady",
            "Vivid"
        ]
        let index = Int.random(in: 0..<words.count)
        return words[index]
    }

    private func startsWithSeedWord(_ message: String, seedWord: String) -> Bool {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let firstWord = trimmed
            .split(whereSeparator: { character in
                character.unicodeScalars.allSatisfy { scalar in
                    CharacterSet.whitespacesAndNewlines.contains(scalar)
                        || CharacterSet.punctuationCharacters.contains(scalar)
                }
            })
            .first
        guard let firstWord else {
            return false
        }
        return firstWord.caseInsensitiveCompare(seedWord) == .orderedSame
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
