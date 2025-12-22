extension PromptMessage {
    func asChatMessage() -> ChatMessage {
        let role: ChatRole
        switch self.role {
        case .system:
            role = .system
        case .user:
            role = .user
        case .assistant:
            role = .assistant
        }

        let content: Content
        switch self.content {
        case let .text(text):
            content = .text(text)
        case .empty:
            content = .empty
        }

        return ChatMessage(role: role, content: content)
    }
}

extension Array where Element == PromptMessage {
    func asChatMessages() -> [ChatMessage] {
        map { $0.asChatMessage() }
    }
}
