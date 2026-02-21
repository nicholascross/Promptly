import Foundation
import PromptlyOpenAIClient
import PromptlyKitUtils

struct ResponsesPromptEndpoint: PromptTurnEndpoint {
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

    func prompt(
        entry: PromptEntry,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        switch entry {
        case let .initial(messages):
            return try await runOnce(
                items: messages.map(RequestItem.message),
                previousResponseId: nil,
                onEvent: onEvent
            )

        case let .resume(context, requestMessages):
            guard case let .responses(previousResponseIdentifier) = context else {
                throw PromptError.invalidConfiguration
            }

            return try await runOnce(
                items: requestMessages.map(RequestItem.message),
                previousResponseId: previousResponseIdentifier,
                onEvent: onEvent
            )

        case let .toolCallResults(context, toolOutputs):
            guard case let .responses(previousResponseIdentifier) = context else {
                throw PromptError.invalidConfiguration
            }

            let outputItems = try toolOutputs.map { output in
                let encodedOutput = try encodeJSONValue(output.output)
                return RequestItem.functionOutput(
                    FunctionCallOutputItem(callId: output.id, output: encodedOutput)
                )
            }

            return try await runOnce(
                items: outputItems,
                previousResponseId: previousResponseIdentifier,
                onEvent: onEvent
            )
        }
    }

    private func runOnce(
        items: [RequestItem],
        previousResponseId: String?,
        onEvent: @escaping @Sendable (PromptStreamEvent) async -> Void
    ) async throws -> PromptTurn {
        var result: ResponseResult
        do {
            result = try await client.createResponse(
                items: items,
                previousResponseId: previousResponseId,
                onTextStream: { fragment in
                    await onEvent(.assistantTextDelta(fragment))
                }
            )
        } catch let error as OpenAIClientError {
            throw promptError(from: error)
        }

        var response = result.response
        while response.status == .inProgress {
            try await Task.sleep(nanoseconds: 200_000_000) // 0.2s
            do {
                response = try await client.retrieveResponse(id: response.id)
            } catch let error as OpenAIClientError {
                throw promptError(from: error)
            }
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
                context: .responses(previousResponseIdentifier: response.id),
                toolCalls: requests,
                resumeToken: response.id
            )
        }

        switch response.status {
        case .completed:
            let combined = response.combinedOutputText()
            let didEmitTextDeltas = result.streamedOutputs.values.contains { !$0.isEmpty }
            if !didEmitTextDeltas, let combined, !combined.isEmpty {
                await onEvent(.assistantTextDelta(combined))
            }
            return PromptTurn(
                context: nil,
                toolCalls: [],
                resumeToken: response.id
            )

        case .requiresAction:
            return PromptTurn(
                context: .responses(previousResponseIdentifier: response.id),
                toolCalls: [],
                resumeToken: response.id
            )

        case .failed:
            throw PromptError.apiError(response.errorMessage ?? "The response failed.")

        case .cancelled:
            throw PromptError.apiError("The response was cancelled.")

        case .inProgress:
            throw PromptError.apiError("The response did not finish.")
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
            throw PromptError.apiError("Failed to encode tool output.")
        }
        return text
    }

    private func promptError(from error: OpenAIClientError) -> PromptError {
        switch error {
        case let .invalidResponse(statusCode):
            return .invalidResponse(statusCode: statusCode)
        case let .apiError(message):
            return .apiError(message)
        }
    }
}
