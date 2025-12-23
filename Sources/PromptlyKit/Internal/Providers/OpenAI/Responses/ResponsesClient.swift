import Foundation
import PromptlyKitUtils

struct ResponsesClient {
    private let factory: ResponsesRequestFactory
    private let decoder: JSONDecoder
    private let transport: any NetworkTransport

    init(
        factory: ResponsesRequestFactory,
        decoder: JSONDecoder,
        transport: any NetworkTransport = URLSessionNetworkTransport()
    ) {
        self.factory = factory
        self.decoder = decoder
        self.transport = transport
    }

    func createResponse(
        items: [RequestItem],
        previousResponseId: String? = nil,
        onTextStream: (@Sendable (String) async -> Void)? = nil
    ) async throws -> ResponseResult {
        let request = try factory.makeCreateRequest(
            items: items,
            previousResponseId: previousResponseId,
            stream: onTextStream != nil
        )

        if let onTextStream {
            return try await sendStream(
                request,
                onTextStream: onTextStream
            )
        }

        let response = try await send(request)
        return ResponseResult(response: response)
    }

    func retrieveResponse(id: String) async throws -> APIResponse {
        let request = factory.makeRetrieveRequest(responseId: id)
        return try await send(request)
    }

    private func send(_ request: URLRequest) async throws -> APIResponse {
        let (data, response) = try await transport.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PrompterError.invalidResponse(statusCode: -1)
        }

        guard 200 ... 299 ~= http.statusCode else {
            let message = decodeErrorMessage(from: data) ?? "HTTP status \(http.statusCode)"
            throw PrompterError.apiError(message)
        }

        return try decoder.decode(APIResponse.self, from: data)
    }

    private func sendStream(
        _ request: URLRequest,
        onTextStream: @escaping @Sendable (String) async -> Void
    ) async throws -> ResponseResult {
        let (lines, response) = try await transport.lineStream(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PrompterError.invalidResponse(statusCode: -1)
        }

        guard 200 ... 299 ~= http.statusCode else {
            var payload = ""
            for try await line in lines {
                payload += line
                payload += "\n"
            }
            let message = decodeErrorMessage(from: Data(payload.utf8)) ?? "HTTP status \(http.statusCode)"
            throw PrompterError.apiError(message)
        }

        var collector = ResponseStreamCollector(
            decoder: decoder,
            onTextStream: onTextStream
        )
        var parser = ServerSentEventParser()

        for try await line in lines {
            if let parsed = parser.feed(line) {
                try await collector.handle(event: parsed.event, data: parsed.data)
            }
        }
        if let parsed = parser.finish() {
            try await collector.handle(event: parsed.event, data: parsed.data)
        }

        let completion = try collector.finish()

        if let response = completion.response {
            let responseIsUseful: Bool = {
                if let text = response.combinedOutputText(), !text.isEmpty { return true }
                if !response.toolCalls().isEmpty { return true }
                return false
            }()

            if !responseIsUseful, let responseId = completion.responseId {
                let retrieved = try await retrieveResponse(id: responseId)
                return ResponseResult(
                    response: retrieved,
                    streamedOutputs: completion.streamedOutputs
                )
            }

            return ResponseResult(
                response: response,
                streamedOutputs: completion.streamedOutputs
            )
        }

        if let responseId = completion.responseId {
            let response = try await retrieveResponse(id: responseId)
            return ResponseResult(
                response: response,
                streamedOutputs: completion.streamedOutputs
            )
        }

        throw PrompterError.apiError("Streaming response missing terminal event.")
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) else { return nil }
        return envelope.error.message
    }
}
