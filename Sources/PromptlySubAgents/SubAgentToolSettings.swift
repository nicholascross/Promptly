import Foundation

struct SubAgentToolSettings: Sendable {
    let defaultToolsConfigURL: URL
    let localToolsConfigURL: URL
    let includeTools: [String]
    let excludeTools: [String]
}
