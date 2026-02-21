import Foundation
import PromptlyDetachedTask
import PromptlyKitUtils

struct SubAgentDetachedTaskRequestAdapter {
    func detachedTaskRequest(
        from request: SubAgentToolRequest
    ) -> DetachedTaskRequest {
        let handoffStrategy: DetachedTaskHandoffStrategy
        let forkedTranscript: [DetachedTaskForkedTranscriptEntry]?

        switch request.handoff {
        case .contextPack:
            handoffStrategy = .contextPack
            forkedTranscript = nil
        case let .forkedContext(entries):
            handoffStrategy = .forkedContext
            forkedTranscript = entries.map { entry in
                DetachedTaskForkedTranscriptEntry(
                    role: entry.role,
                    content: entry.content
                )
            }
        }

        return DetachedTaskRequest(
            task: request.task,
            goals: request.goals,
            constraints: request.constraints,
            contextPack: contextPack(from: request.contextPack),
            handoffStrategy: handoffStrategy,
            forkedTranscript: forkedTranscript,
            resumeId: request.resumeId
        )
    }

    private func contextPack(
        from value: JSONValue?
    ) -> DetachedTaskContextPack? {
        guard let value else {
            return nil
        }
        if let decoded = try? value.decoded(DetachedTaskContextPack.self) {
            return decoded
        }
        if let summary = encodedJSONText(from: value) {
            return DetachedTaskContextPack(
                summary: summary,
                snippets: nil,
                notes: nil
            )
        }
        return nil
    }

    private func encodedJSONText(from value: JSONValue) -> String? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(value) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }
}

struct SubAgentDetachedTaskPayloadAdapter {
    func jsonValue(
        from payload: DetachedTaskReturnPayload
    ) -> JSONValue {
        if let jsonValue = try? JSONValue(payload) {
            return jsonValue
        }
        return .object([
            "result": .string(payload.result),
            "summary": .string(payload.summary)
        ])
    }
}
