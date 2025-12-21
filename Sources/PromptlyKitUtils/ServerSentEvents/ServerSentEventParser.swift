import Foundation

public struct ServerSentEventParser {
    public struct ParsedEvent {
        public let event: String?
        public let data: String
    }

    private var event: String?
    private var dataLines: [String] = []

    public init() {}

    public mutating func feed(_ line: String) -> ParsedEvent? {
        if line.isEmpty {
            return flush()
        }

        if line.hasPrefix("id:") {
            // Reconnection is not supported, so we intentionally ignore id fields.
            return nil
        }

        if line.hasPrefix("retry:") {
            // Retry hints only matter for reconnection; ignoring keeps intent explicit.
            return nil
        }

        if line.hasPrefix(":") {
            // Leading colon is an SSE comment; propagate nothing downstream.
            return nil
        }

        if line.hasPrefix("event:") {
            event = cleanedValue(from: line, prefix: "event:")
            return nil
        }

        if line.hasPrefix("data:") {
            dataLines.append(cleanedValue(from: line, prefix: "data:"))
        }
        return nil
    }

    public mutating func finish() -> ParsedEvent? {
        return flush()
    }

    private mutating func flush() -> ParsedEvent? {
        guard !dataLines.isEmpty else {
            event = nil
            return nil
        }

        let data = dataLines.joined(separator: "\n")
        let parsed = ParsedEvent(event: event, data: data)
        event = nil
        dataLines.removeAll(keepingCapacity: true)
        return parsed
    }

    private func cleanedValue(from line: String, prefix: String) -> String {
        let start = line.index(line.startIndex, offsetBy: prefix.count)
        var value = line[start...]
        if value.first == " " {
            value.removeFirst()
        }
        return String(value)
    }
}
