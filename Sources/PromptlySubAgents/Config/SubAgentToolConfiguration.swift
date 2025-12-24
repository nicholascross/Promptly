import Foundation

struct SubAgentToolConfiguration: Decodable, Sendable {
    let toolsFileName: String?
    let include: [String]?
    let exclude: [String]?

    init(toolsFileName: String?, include: [String]?, exclude: [String]?) {
        self.toolsFileName = toolsFileName
        self.include = include
        self.exclude = exclude
    }
}
