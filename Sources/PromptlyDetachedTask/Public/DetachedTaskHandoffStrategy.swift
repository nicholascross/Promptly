import Foundation

public enum DetachedTaskHandoffStrategy: String, Codable, Sendable {
    case contextPack
    case forkedContext

    public func validate(request: DetachedTaskRequest) throws {
        switch self {
        case .contextPack:
            return
        case .forkedContext:
            try validateForkedTranscript(in: request)
        }
    }
}

public struct DetachedTaskForkedTranscriptEntry: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}

public enum DetachedTaskValidationError: Error, LocalizedError, Sendable {
    case emptyTask
    case missingForkedTranscript
    case emptyForkedTranscript
    case emptyForkedTranscriptRole(index: Int)
    case invalidForkedTranscriptRole(index: Int, role: String)
    case emptyForkedTranscriptContent(index: Int)
    case forkedTranscriptTooLarge(maximumMessageCount: Int, maximumCharacterCount: Int)

    public var errorDescription: String? {
        switch self {
        case .emptyTask:
            return "Task must be provided."
        case .missingForkedTranscript:
            return "Forked transcript is required when handoffStrategy is forkedContext."
        case .emptyForkedTranscript:
            return "Forked transcript must include at least one entry."
        case let .emptyForkedTranscriptRole(index):
            return "Forked transcript entry \(index + 1) is missing a role."
        case let .invalidForkedTranscriptRole(index, role):
            return "Forked transcript entry \(index + 1) has unsupported role \(role)."
        case let .emptyForkedTranscriptContent(index):
            return "Forked transcript entry \(index + 1) is missing content."
        case let .forkedTranscriptTooLarge(maximumMessageCount, maximumCharacterCount):
            return "Forked transcript exceeds limits (\(maximumMessageCount) messages, \(maximumCharacterCount) characters)."
        }
    }
}

private extension DetachedTaskHandoffStrategy {
    func validateForkedTranscript(in request: DetachedTaskRequest) throws {
        guard let entries = request.forkedTranscript else {
            if request.hasValidResumeIdentifier {
                return
            }
            throw DetachedTaskValidationError.missingForkedTranscript
        }
        if entries.isEmpty {
            if request.hasValidResumeIdentifier {
                return
            }
            throw DetachedTaskValidationError.emptyForkedTranscript
        }
        _ = try DetachedTaskForkedTranscriptValidator.validatedEntries(entries)
    }
}
