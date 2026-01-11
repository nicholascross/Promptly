import Foundation

enum SubAgentHandoff: Sendable {
    case contextPack
    case forkedContext([SubAgentForkedTranscriptEntry])
}

struct SubAgentForkedTranscriptEntry: Decodable, Sendable {
    let role: String
    let content: String
}
