import PromptlyKitUtils

struct SubAgentToolRequest: Decodable, Sendable {
    let task: String
    let contextPack: JSONValue?
    let goals: [String]?
    let constraints: [String]?
    let resumeId: String?
}
