import Foundation

struct SubAgentToolSettings: Sendable {
    let toolsFileName: String
    let includeTools: [String]
    let excludeTools: [String]
}
