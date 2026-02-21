import Foundation

enum SubAgentResumeIdentifier {
    static func isValid(_ resumeIdentifier: String?) -> Bool {
        guard let resumeIdentifier else {
            return false
        }
        let trimmedIdentifier = resumeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            return false
        }
        return UUID(uuidString: trimmedIdentifier) != nil
    }
}
