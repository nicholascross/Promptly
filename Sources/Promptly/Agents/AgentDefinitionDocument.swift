import Foundation

struct AgentDefinitionDocument: Encodable {
    let name: String
    let description: String
    let supervisorHint: String?
    let systemPrompt: String
    let tools: AgentToolOverrides?
}
