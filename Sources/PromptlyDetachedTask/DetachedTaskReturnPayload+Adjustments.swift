extension DetachedTaskReturnPayload {
    func withResumeId(_ resumeId: String?) -> DetachedTaskReturnPayload {
        DetachedTaskReturnPayload(
            result: result,
            summary: summary,
            artifacts: artifacts,
            evidence: evidence,
            confidence: confidence,
            needsMoreInformation: needsMoreInformation,
            requestedInformation: requestedInformation,
            needsSupervisorDecision: needsSupervisorDecision,
            decisionReason: decisionReason,
            nextActionAdvice: nextActionAdvice,
            resumeId: resumeId,
            logPath: logPath,
            supervisorMessage: supervisorMessage
        )
    }

    func withLogPath(_ logPath: String?) -> DetachedTaskReturnPayload {
        DetachedTaskReturnPayload(
            result: result,
            summary: summary,
            artifacts: artifacts,
            evidence: evidence,
            confidence: confidence,
            needsMoreInformation: needsMoreInformation,
            requestedInformation: requestedInformation,
            needsSupervisorDecision: needsSupervisorDecision,
            decisionReason: decisionReason,
            nextActionAdvice: nextActionAdvice,
            resumeId: resumeId,
            logPath: logPath,
            supervisorMessage: supervisorMessage
        )
    }
}
