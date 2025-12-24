import Foundation

struct SubAgentDefinition: Decodable, Sendable {
    let name: String
    let description: String
    let systemPrompt: String
    let tools: SubAgentToolConfiguration?

    init(
        name: String,
        description: String,
        systemPrompt: String,
        tools: SubAgentToolConfiguration?
    ) {
        self.name = name
        self.description = description
        self.systemPrompt = systemPrompt
        self.tools = tools
    }
}
