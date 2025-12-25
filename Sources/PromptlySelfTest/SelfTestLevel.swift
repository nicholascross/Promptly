import Foundation

public enum SelfTestLevel: String, CaseIterable, Codable, Sendable {
    case basic
    case tools
    case agents

    public var summary: String {
        switch self {
        case .basic:
            return "Fast checks plus a short model conversation."
        case .tools:
            return "Checks tool loading and invokes a tool through the model."
        case .agents:
            return "Checks sub agent configuration and runs a model-backed agent."
        }
    }
}
