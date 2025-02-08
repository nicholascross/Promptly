struct ChatResponse: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]

}

struct Choice: Decodable {
    let index: Int?
    let delta: Delta?
}

struct Delta: Decodable {
    let role: String?
    let content: String?
}
