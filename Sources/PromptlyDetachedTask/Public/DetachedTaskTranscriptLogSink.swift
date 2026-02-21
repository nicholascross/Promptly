import Foundation
import PromptlyKit
import PromptlyKitUtils

public actor DetachedTaskTranscriptLogSink: DetachedTaskLogSink {
    private struct LogEntry: Encodable {
        let timestamp: String
        let runIdentifier: String
        let eventType: String
        let data: JSONValue
    }

    public nonisolated let logPath: String?

    private let runIdentifier: String
    private let fileManager: FileManagerProtocol
    private let logFileURL: URL
    private let encoder: JSONEncoder
    private let dateProvider: @Sendable () -> Date
    private let timestampFormatter: ISO8601DateFormatter
    private var hasFinished = false

    public init(
        logsDirectoryURL: URL,
        fileManager: FileManagerProtocol,
        dateProvider: @Sendable @escaping () -> Date = Date.init
    ) throws {
        let logsDirectory = logsDirectoryURL.standardizedFileURL

        try fileManager.createDirectory(
            at: logsDirectory,
            withIntermediateDirectories: true,
            attributes: nil
        )

        runIdentifier = UUID().uuidString.lowercased()
        let fileTimestamp = Self.fileTimestamp(from: dateProvider())
        let logFileURL = logsDirectory.appendingPathComponent(
            "\(fileTimestamp)-\(runIdentifier).jsonl"
        )
        _ = fileManager.createFile(
            atPath: logFileURL.path,
            contents: nil,
            attributes: nil
        )

        self.fileManager = fileManager
        self.logFileURL = logFileURL
        self.logPath = logFileURL.path
        self.encoder = JSONEncoder()
        self.dateProvider = dateProvider
        self.timestampFormatter = ISO8601DateFormatter()
        self.timestampFormatter.formatOptions = [.withInternetDateTime]
    }

    public func handle(event: PromptStreamEvent) async {
        switch event {
        case let .assistantTextDelta(text):
            log(
                eventType: EventType.assistantText,
                data: .object([
                    "text": .string(text)
                ])
            )
        case let .toolCallRequested(identifier, name, arguments):
            log(
                eventType: EventType.toolCallRequested,
                data: .object([
                    "identifier": jsonValue(for: identifier),
                    "name": .string(name),
                    "arguments": arguments
                ])
            )
        case let .toolCallCompleted(identifier, name, output):
            log(
                eventType: EventType.toolCallCompleted,
                data: .object([
                    "identifier": jsonValue(for: identifier),
                    "name": .string(name),
                    "output": output
                ])
            )
        }
    }

    public func recordCompletion(
        payload: DetachedTaskReturnPayload,
        didUseFallbackPayload: Bool
    ) async {
        guard !hasFinished else { return }
        hasFinished = true

        log(
            eventType: EventType.returnPayload,
            data: returnPayloadJSONValue(payload)
        )
        let status = didUseFallbackPayload ? "missing_return_payload" : "completed"
        log(
            eventType: EventType.runtimeStop,
            data: .object([
                "status": .string(status)
            ])
        )
    }

    public func recordFailure(_ error: Error) async {
        guard !hasFinished else { return }
        hasFinished = true

        log(
            eventType: EventType.runtimeStop,
            data: .object([
                "status": .string("failed"),
                "errorDescription": .string(error.localizedDescription)
            ])
        )
    }

    private func log(eventType: String, data: JSONValue) {
        let entry = LogEntry(
            timestamp: timestampFormatter.string(from: dateProvider()),
            runIdentifier: runIdentifier,
            eventType: eventType,
            data: data
        )

        do {
            var encoded = try encoder.encode(entry)
            encoded.append(0x0A)
            try fileManager.appendData(encoded, to: logFileURL)
        } catch {
            // Ignore encoding failures to keep the detached task run moving.
        }
    }

    private func returnPayloadJSONValue(
        _ payload: DetachedTaskReturnPayload
    ) -> JSONValue {
        if let jsonValue = try? JSONValue(payload) {
            return jsonValue
        }
        return .object([
            "result": .string(payload.result),
            "summary": .string(payload.summary)
        ])
    }

    private func jsonValue(for identifier: String?) -> JSONValue {
        guard let identifier else {
            return .null
        }
        return .string(identifier)
    }

    private static func fileTimestamp(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        let timestamp = formatter.string(from: date)
        return timestamp.replacingOccurrences(of: ":", with: "-")
    }
}

private enum EventType {
    static let assistantText = "assistant_text"
    static let toolCallRequested = "tool_call_requested"
    static let toolCallCompleted = "tool_call_completed"
    static let returnPayload = "return_payload"
    static let runtimeStop = "runtime_stop"
}
