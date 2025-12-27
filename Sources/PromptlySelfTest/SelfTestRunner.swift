import Foundation
import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import PromptlySubAgents

public struct SelfTestRunner: Sendable {
    public let configurationFileURL: URL
    public let toolsFileName: String
    private let fileManager: FileManagerProtocol

    public init(
        configurationFileURL: URL,
        toolsFileName: String = "tools",
        fileManager: FileManagerProtocol = FileManager.default
    ) {
        self.configurationFileURL = configurationFileURL.standardizedFileURL
        self.toolsFileName = toolsFileName
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

        guard configurationResult.configuration != nil else {
            results.append(
                SelfTestResult(
                    name: "Sub agent lifecycle",
                    status: .failed,
                    details: "Agent tests require a valid configuration."
                )
            )
            return results
        }

        results.append(
            await runTestWithOutput(name: "Sub agent lifecycle") {
                let payload = try await verifySubAgentLifecycle()
                return SelfTestResult(
                    name: "Sub agent lifecycle",
                    status: .passed,
                    agentOutput: payload
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
        let coordinator = try PrompterCoordinator(config: configuration)
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

            let coordinator = try PrompterCoordinator(config: configuration, tools: [listTool, dateTool])
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

    private func verifySubAgentLifecycle() async throws -> JSONValue {
        return try await withTemporaryConfigurationCopy { temporaryConfigurationFileURL, agentsDirectoryURL in
            let agentName = "Self Test Agent"
            let agentConfigurationURL = try createTemporaryAgentConfiguration(
                agentsDirectoryURL: agentsDirectoryURL,
                agentName: agentName
            )

            let toolFactory = SubAgentToolFactory(
                fileManager: fileManager,
                credentialSource: SystemCredentialSource()
            )
            let defaultToolsConfigurationURL = ToolFactory.defaultToolsConfigURL(
                fileManager: fileManager,
                toolsFileName: toolsFileName
            )
            let localToolsConfigurationURL = ToolFactory.localToolsConfigURL(
                fileManager: fileManager,
                toolsFileName: toolsFileName
            )

            let tools = try toolFactory.makeTools(
                configurationFileURL: temporaryConfigurationFileURL,
                defaultToolsConfigURL: defaultToolsConfigurationURL,
                localToolsConfigURL: localToolsConfigurationURL,
                includeTools: [],
                excludeTools: [],
                toolOutput: { _ in }
            )

            let expectedToolName = "SubAgent-\(normalizedIdentifier(from: agentName))"
            guard let agentTool = tools.first(where: { $0.name == expectedToolName }) else {
                throw SelfTestFailure("Expected sub agent tool was not created.")
            }

            let requestPayload: JSONValue = .object([
                "task": .string("Return a short summary confirming the self test ran."),
                "goals": .array([
                    .string("Call ReturnToSupervisor with required fields."),
                    .string("Keep the response brief.")
                ]),
                "constraints": .array([
                    .string("Do not use any tools besides ReturnToSupervisor."),
                    .string("Do not modify any files.")
                ])
            ])

            let payload = try await agentTool.execute(arguments: requestPayload)
            try validateSubAgentPayload(payload)

            try fileManager.removeItem(atPath: agentConfigurationURL.path)
            if fileManager.fileExists(atPath: agentConfigurationURL.path) {
                throw SelfTestFailure("Failed to remove temporary agent configuration file.")
            }
            return payload
        }
    }

    private func createTemporaryAgentConfiguration(
        agentsDirectoryURL: URL,
        agentName: String
    ) throws -> URL {
        let toolConfiguration: [String: JSONValue] = [
            "include": .array([.string("self-test-disabled")])
        ]
        let agentDefinition: [String: JSONValue] = [
            "name": .string(agentName),
            "description": .string("Temporary agent used by self tests."),
            "systemPrompt": .string(
                "Complete the task and call ReturnToSupervisor exactly once with result and summary fields."
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
