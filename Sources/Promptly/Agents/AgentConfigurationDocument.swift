import Foundation

struct AgentConfigurationDocument: Encodable {
    let model: String?
    let provider: String?
    let api: String?
    let agent: AgentDefinitionDocument
}
