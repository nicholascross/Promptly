import Foundation

struct AgentToolOverrides: Encodable {
    let toolsFileName: String?
    let include: [String]?
    let exclude: [String]?
}
