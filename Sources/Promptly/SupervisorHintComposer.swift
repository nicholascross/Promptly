import PromptlyKit

func insertSupervisorHintMessage(
    supervisorHint: String?,
    into initialMessages: [PromptMessage]
) -> [PromptMessage] {
    guard let supervisorHint else {
        return initialMessages
    }
    let trimmedHint = supervisorHint.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !trimmedHint.isEmpty else {
        return initialMessages
    }

    let hintMessage = PromptMessage(role: .system, content: .text(trimmedHint))
    var messages = initialMessages
    if let firstNonSystemIndex = messages.firstIndex(where: { $0.role != .system }) {
        messages.insert(hintMessage, at: firstNonSystemIndex)
    } else {
        messages.append(hintMessage)
    }
    return messages
}
