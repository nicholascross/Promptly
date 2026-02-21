import Foundation

public struct SelfTestNamedToolOutput: Codable, Sendable {
    public let name: String
    public let output: SelfTestToolOutput

    public init(name: String, output: SelfTestToolOutput) {
        self.name = name
        self.output = output
    }
}
