import Foundation

struct ResponsesClient {
    private let factory: ResponsesRequestFactory
    private let decoder: JSONDecoder

    init(factory: ResponsesRequestFactory, decoder: JSONDecoder) {
        self.factory = factory
        self.decoder = decoder
    }

    func createResponse(
        items: [RequestItem],
        previousResponseId: String? = nil,
        onTextStream: ((String) -> Void)? = nil
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
        let (data, response) = try await URLSession.shared.data(for: request)
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
        onTextStream: @escaping (String) -> Void
    ) async throws -> ResponseResult {
        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw PrompterError.invalidResponse(statusCode: -1)
        }

        guard 200 ... 299 ~= http.statusCode else {
            var data = Data()
            for try await chunk in bytes {
                data.append(chunk)
            }
            let message = decodeErrorMessage(from: data) ?? "HTTP status \(http.statusCode)"
            throw PrompterError.apiError(message)
        }

        var collector = ResponseStreamCollector(
            decoder: decoder,
            onTextStream: onTextStream
        )
        var parser = ServerSentEventParser()

        for try await line in bytes.lines {
            if let parsed = parser.feed(line) {
                try collector.handle(event: parsed.event, data: parsed.data)
            }
        }
        if let parsed = parser.finish() {
            try collector.handle(event: parsed.event, data: parsed.data)
        }

        let completion = try collector.finish()

        if let response = completion.response {
            return ResponseResult(response: response, streamedOutputs: completion.streamedOutputs)
        }

        if let responseId = completion.responseId {
            let response = try await retrieveResponse(id: responseId)
            return ResponseResult(response: response, streamedOutputs: completion.streamedOutputs)
        }

        throw PrompterError.apiError("Streaming response missing terminal event.")
    }

    private func decodeErrorMessage(from data: Data) -> String? {
        guard let envelope = try? decoder.decode(APIErrorEnvelope.self, from: data) else { return nil }
        return envelope.error.message
    }
}
