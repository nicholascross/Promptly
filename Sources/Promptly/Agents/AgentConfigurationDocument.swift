import Foundation

struct AgentConfigurationDocument: Encodable {
    let model: String?
    let provider: String?
    let api: String?
    let agent: AgentDefinitionDocument
}

struct AgentDefinitionDocument: Encodable {
    let name: String
    let description: String
    let systemPrompt: String
    let tools: AgentToolOverrides?
}

struct AgentToolOverrides: Encodable {
    let toolsFileName: String?
    let include: [String]?
    let exclude: [String]?
}
