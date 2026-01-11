import Foundation

public struct DetachedTaskReturnPayload: Codable, Sendable {
    public let result: String
    public let summary: String
    public let artifacts: [DetachedTaskArtifact]?
    public let evidence: [String]?
    public let confidence: Double?
    public let needsMoreInformation: Bool?
    public let requestedInformation: [String]?
    public let needsSupervisorDecision: Bool?
    public let decisionReason: String?
    public let nextActionAdvice: String?
    public let resumeId: String?
    public let logPath: String?
    public let supervisorMessage: DetachedTaskSupervisorMessage?

    public init(
        result: String,
        summary: String,
        artifacts: [DetachedTaskArtifact]?,
        evidence: [String]?,
        confidence: Double?,
        needsMoreInformation: Bool?,
        requestedInformation: [String]?,
        needsSupervisorDecision: Bool?,
        decisionReason: String?,
        nextActionAdvice: String?,
        resumeId: String?,
        logPath: String?,
        supervisorMessage: DetachedTaskSupervisorMessage?
    ) {
        self.result = result
        self.summary = summary
        self.artifacts = artifacts
        self.evidence = evidence
        self.confidence = confidence
        self.needsMoreInformation = needsMoreInformation
        self.requestedInformation = requestedInformation
        self.needsSupervisorDecision = needsSupervisorDecision
        self.decisionReason = decisionReason
        self.nextActionAdvice = nextActionAdvice
        self.resumeId = resumeId
        self.logPath = logPath
        self.supervisorMessage = supervisorMessage
    }
}

public struct DetachedTaskArtifact: Codable, Sendable {
    public let type: String
    public let description: String
    public let path: String?
    public let command: String?
    public let content: String?

    public init(
        type: String,
        description: String,
        path: String?,
        command: String?,
        content: String?
    ) {
        self.type = type
        self.description = description
        self.path = path
        self.command = command
        self.content = content
    }
}

public struct DetachedTaskSupervisorMessage: Codable, Sendable {
    public let role: String
    public let content: String

    public init(role: String, content: String) {
        self.role = role
        self.content = content
    }
}
