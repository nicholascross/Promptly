import Foundation

struct SubAgentDefinition: Decodable, Sendable {
    let name: String
    let description: String
    let supervisorHint: String?
    let systemPrompt: String
    let tools: SubAgentToolConfiguration?

    init(
        name: String,
        description: String,
        supervisorHint: String?,
        systemPrompt: String,
        tools: SubAgentToolConfiguration?
    ) {
        self.name = name
        self.description = description
        self.supervisorHint = supervisorHint
        self.systemPrompt = systemPrompt
        self.tools = tools
    }
}
