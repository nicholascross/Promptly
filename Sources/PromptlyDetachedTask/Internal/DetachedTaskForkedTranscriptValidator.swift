import PromptlyKit

struct DetachedTaskValidatedForkedTranscriptEntry: Sendable {
    let role: PromptRole
    let content: String
}

struct DetachedTaskForkedTranscriptValidator {
    static let maximumMessageCount = 40
    static let maximumCharacterCount = 20000

    static func validatedEntries(
        _ entries: [DetachedTaskForkedTranscriptEntry]
    ) throws -> [DetachedTaskValidatedForkedTranscriptEntry] {
        guard !entries.isEmpty else {
            throw DetachedTaskValidationError.emptyForkedTranscript
        }

        var totalCharacters = 0
        var validatedEntries: [DetachedTaskValidatedForkedTranscriptEntry] = []
        validatedEntries.reserveCapacity(entries.count)

        for (index, entry) in entries.enumerated() {
            let trimmedRole = entry.role.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedRole.isEmpty else {
                throw DetachedTaskValidationError.emptyForkedTranscriptRole(index: index)
            }
            let normalizedRole = trimmedRole.lowercased()
            let role: PromptRole
            switch normalizedRole {
            case "user":
                role = .user
            case "assistant":
                role = .assistant
            default:
                throw DetachedTaskValidationError.invalidForkedTranscriptRole(
                    index: index,
                    role: entry.role
                )
            }

            let trimmedContent = entry.content.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedContent.isEmpty else {
                throw DetachedTaskValidationError.emptyForkedTranscriptContent(index: index)
            }

            totalCharacters += entry.content.count
            if validatedEntries.count + 1 > maximumMessageCount
                || totalCharacters > maximumCharacterCount {
                throw DetachedTaskValidationError.forkedTranscriptTooLarge(
                    maximumMessageCount: maximumMessageCount,
                    maximumCharacterCount: maximumCharacterCount
                )
            }

            validatedEntries.append(
                DetachedTaskValidatedForkedTranscriptEntry(
                    role: role,
                    content: entry.content
                )
            )
        }

        return validatedEntries
    }
}
