import Foundation

struct AgentDefinitionDocument: Encodable {
    let name: String
    let description: String
    let systemPrompt: String
    let tools: AgentToolOverrides?
}
