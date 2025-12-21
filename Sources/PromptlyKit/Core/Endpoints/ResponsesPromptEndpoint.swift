import Foundation
import PromptlyKitUtils

struct ResponsesPromptEndpoint: PromptEndpoint {
    private let client: ResponsesClient
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init(
        client: ResponsesClient,
        encoder: JSONEncoder,
        decoder: JSONDecoder
    ) {
        self.client = client
        self.encoder = encoder
        self.decoder = decoder
    }

    func start(
        messages: [ChatMessage],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        try await runOnce(
            items: messages.map(RequestItem.message),
            previousResponseId: nil,
            onEvent: onEvent
        )
    }

    func continueSession(
        continuation: PromptContinuation,
        toolOutputs: [ToolCallOutput],
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        guard case let .responses(previousResponseId) = continuation else {
            throw PrompterError.invalidConfiguration
        }

        let outputItems = try toolOutputs.map { output in
            let encodedOutput = try encodeJSONValue(output.output)
            return RequestItem.functionOutput(
                FunctionCallOutputItem(callId: output.id, output: encodedOutput)
            )
        }

        return try await runOnce(
            items: outputItems,
            previousResponseId: previousResponseId,
            onEvent: onEvent
        )
    }

    private func runOnce(
        items: [RequestItem],
        previousResponseId: String?,
        onEvent: @escaping @Sendable (PromptStreamEvent) -> Void
    ) async throws -> PromptTurn {
        var streamedText = ""
        var result = try await client.createResponse(
            items: items,
            previousResponseId: previousResponseId,
            onTextStream: { fragment in
                streamedText += fragment
                onEvent(.assistantTextDelta(fragment))
            }
        )

        var response = result.response
        while response.status == .inProgress {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            response = try await client.retrieveResponse(id: response.id)
            result = ResponseResult(response: response, streamedOutputs: result.streamedOutputs)
        }

        let calls = response.toolCalls()
        if !calls.isEmpty {
            let requests = calls.map { call in
                ToolCallRequest(
                    id: call.callId,
                    name: call.function.name,
                    arguments: decodeArguments(call.function.arguments)
                )
            }

            return PromptTurn(
                continuation: .responses(previousResponseId: response.id),
                toolCalls: requests,
                finalAssistantText: nil
            )
        }

        switch response.status {
        case .completed:
            let combined = response.combinedOutputText()
            let finalText: String?
            if let combined, !combined.isEmpty {
                finalText = combined
            } else if !streamedText.isEmpty {
                finalText = streamedText
            } else {
                finalText = combined
            }
            return PromptTurn(
                continuation: nil,
                toolCalls: [],
                finalAssistantText: finalText
            )

        case .requiresAction:
            return PromptTurn(
                continuation: .responses(previousResponseId: response.id),
                toolCalls: [],
                finalAssistantText: nil
            )

        case .failed:
            throw PrompterError.apiError(response.errorMessage ?? "The response failed.")

        case .cancelled:
            throw PrompterError.apiError("The response was cancelled.")

        case .inProgress:
            throw PrompterError.apiError("The response did not finish.")
        }
    }

    private func decodeArguments(_ raw: String) -> JSONValue {
        guard
            let data = raw.data(using: .utf8),
            let value = try? decoder.decode(JSONValue.self, from: data)
        else {
            return .string(raw)
        }
        return value
    }

    private func encodeJSONValue(_ value: JSONValue) throws -> String {
        let data = try encoder.encode(value)
        guard let text = String(data: data, encoding: .utf8) else {
            throw PrompterError.apiError("Failed to encode tool output.")
        }
        return text
    }
}
