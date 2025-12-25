import Foundation
import PromptlyKitUtils

public enum SelfTestStatus: String, Codable, Sendable {
    case passed
    case failed
}

public struct SelfTestResult: Codable, Sendable {
    public let name: String
    public let status: SelfTestStatus
    public let details: String?
    public let modelOutput: String?
    public let toolOutput: SelfTestToolOutput?
    public let toolOutputs: [SelfTestNamedToolOutput]?
    public let agentOutput: JSONValue?

    public init(
        name: String,
        status: SelfTestStatus,
        details: String? = nil,
        modelOutput: String? = nil,
        toolOutput: SelfTestToolOutput? = nil,
        toolOutputs: [SelfTestNamedToolOutput]? = nil,
        agentOutput: JSONValue? = nil
    ) {
        self.name = name
        self.status = status
        self.details = details
        self.modelOutput = modelOutput
        self.toolOutput = toolOutput
        self.toolOutputs = toolOutputs
        self.agentOutput = agentOutput
    }
}

public struct SelfTestToolOutput: Codable, Sendable {
    public let exitCode: Int
    public let output: String

    public init(exitCode: Int, output: String) {
        self.exitCode = exitCode
        self.output = output
    }
}

public struct SelfTestNamedToolOutput: Codable, Sendable {
    public let name: String
    public let output: SelfTestToolOutput

    public init(name: String, output: SelfTestToolOutput) {
        self.name = name
        self.output = output
    }
}

public struct SelfTestSummary: Codable, Sendable {
    public let level: SelfTestLevel
    public let status: SelfTestStatus
    public let passedCount: Int
    public let failedCount: Int
    public let results: [SelfTestResult]

    public init(level: SelfTestLevel, results: [SelfTestResult]) {
        self.level = level
        self.results = results
        let passedCount = results.filter { $0.status == .passed }.count
        let failedCount = results.filter { $0.status == .failed }.count
        self.passedCount = passedCount
        self.failedCount = failedCount
        self.status = failedCount == 0 ? .passed : .failed
    }
}
