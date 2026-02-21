import Foundation
import PromptlyKitUtils

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
