import Foundation

public struct DetachedTaskRequest: Codable, Sendable {
    public let task: String
    public let goals: [String]?
    public let constraints: [String]?
    public let contextPack: DetachedTaskContextPack?
    public let handoffStrategy: DetachedTaskHandoffStrategy
    public let forkedTranscript: [DetachedTaskForkedTranscriptEntry]?
    public let resumeId: String?

    public init(
        task: String,
        goals: [String]?,
        constraints: [String]?,
        contextPack: DetachedTaskContextPack?,
        handoffStrategy: DetachedTaskHandoffStrategy,
        forkedTranscript: [DetachedTaskForkedTranscriptEntry]?,
        resumeId: String?
    ) {
        self.task = task
        self.goals = goals
        self.constraints = constraints
        self.contextPack = contextPack
        self.handoffStrategy = handoffStrategy
        self.forkedTranscript = forkedTranscript
        self.resumeId = resumeId
    }

    public func validate() throws {
        let trimmedTask = task.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTask.isEmpty else {
            throw DetachedTaskValidationError.emptyTask
        }
        try handoffStrategy.validate(request: self)
    }
}

public struct DetachedTaskContextPack: Codable, Sendable {
    public let summary: String?
    public let snippets: [DetachedTaskContextSnippet]?
    public let notes: [String]?

    public init(
        summary: String?,
        snippets: [DetachedTaskContextSnippet]?,
        notes: [String]?
    ) {
        self.summary = summary
        self.snippets = snippets
        self.notes = notes
    }
}

public struct DetachedTaskContextSnippet: Codable, Sendable {
    public let path: String
    public let content: String
    public let startLine: Int?
    public let endLine: Int?

    public init(
        path: String,
        content: String,
        startLine: Int?,
        endLine: Int?
    ) {
        self.path = path
        self.content = content
        self.startLine = startLine
        self.endLine = endLine
    }
}

extension DetachedTaskRequest {
    var hasValidResumeIdentifier: Bool {
        guard let resumeIdentifier = resumeId else {
            return false
        }
        let trimmedIdentifier = resumeIdentifier.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedIdentifier.isEmpty else {
            return false
        }
        return UUID(uuidString: trimmedIdentifier) != nil
    }
}
