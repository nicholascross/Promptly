import Foundation

public struct ResponseStreamCollector {
    public let decoder: JSONDecoder
    public let onTextStream: @Sendable (String) async -> Void

    public private(set) var streamedOutputs: [Int: String] = [:]
    private var finalResponse: APIResponse?
    private var failure: OpenAIClientError?
    private var responseId: String?

    public init(decoder: JSONDecoder, onTextStream: @escaping @Sendable (String) async -> Void) {
        self.decoder = decoder
        self.onTextStream = onTextStream
    }

    public mutating func handle(event: String?, data: String) async throws {
        guard data != "[DONE]" else { return }

        guard let payloadData = data.data(using: .utf8) else { return }

        do {
            let payload = try decoder.decode(ResponseStreamPayload.self, from: payloadData)
            try await process(payload: payload)
        } catch {
            let segments = data
                .split(whereSeparator: { $0 == "\n" })
                .map { String($0) }
                .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

            guard segments.count > 1 else {
                return
            }

            for segment in segments {
                guard let segmentData = segment.data(using: .utf8) else { continue }
                do {
                    let payload = try decoder.decode(ResponseStreamPayload.self, from: segmentData)
                    try await process(payload: payload)
                } catch {
                    // TODO: swallowed error, consider logging
                }
            }
        }
    }

    public mutating func finish() throws -> ResponseStreamCompletion {
        if let failure {
            throw failure
        }

        if let response = finalResponse {
            return ResponseStreamCompletion(
                response: response,
                streamedOutputs: streamedOutputs,
                responseId: responseId ?? response.id
            )
        }

        return ResponseStreamCompletion(
            response: nil,
            streamedOutputs: streamedOutputs,
            responseId: responseId
        )
    }

    // swiftlint:disable:next cyclomatic_complexity
    private mutating func process(payload: ResponseStreamPayload) async throws {
        if let id = payload.response?.id ?? payload.responseId {
            responseId = id
        }

        switch payload.type {
        case "response.output_text.delta", "response.message.delta":
            if let text = payload.delta?.textFragment, !text.isEmpty {
                await onTextStream(text)
                let index = payload.outputIndex ?? 0
                streamedOutputs[index, default: ""] += text
            }
        case "response.output_text.done":
            break
        case "response.completed", "response.requires_action":
            if let response = payload.response {
                finalResponse = response
            }
        case "response.failed":
            if let response = payload.response {
                finalResponse = response
            }
            let message = payload.error?.message ?? "The response failed."
            failure = OpenAIClientError.apiError(message)
        case "response.cancelled":
            if let response = payload.response {
                finalResponse = response
            }
            failure = OpenAIClientError.apiError("The response was cancelled.")
        case "response.error":
            let message = payload.error?.message ?? "The response failed."
            failure = OpenAIClientError.apiError(message)
        default:
            // TODO: unknown event type, consider logging
            // https://platform.openai.com/docs/api-reference/responses-streaming/response
            break
        }
    }
}
