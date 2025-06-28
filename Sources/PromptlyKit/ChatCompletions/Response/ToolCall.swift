import Foundation

enum StreamEvent: Sendable {
    case content(String)
    case toolCall(id: String, name: String, args: JSONValue)
    case stop
}

actor ResponseProcessor {
    private let prefix = "data: "

    private var pendingToolId: String?
    private var pendingToolName: String?
    private var pendingArgs = ""

    func process(line: String) throws -> [StreamEvent] {
        guard line.hasPrefix(prefix) else { return [] }

        let payload = String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if payload == "[DONE]" {
            return []
        }

        let chunk = try JSONDecoder().decode(
            ChatCompletionChunk.self,
            from: Data(payload.utf8)
        )

        // Deliberately ignore possibility of multiple choices
        guard let choice = chunk.choices.first else { return [] }

        var output: [StreamEvent] = []

        if let txt = choice.delta.content, !txt.isEmpty {
            output.append(.content(txt))
        }

        if let calls = choice.delta.toolCalls {
            for raw in calls {
                if
                    let id = raw.id,
                    let name = raw.function.name
                {
                    // start a new buffer
                    pendingToolId = id
                    pendingToolName = name
                    pendingArgs = raw.function.arguments
                } else if pendingToolName != nil {
                    // append to existing buffer
                    pendingArgs += raw.function.arguments
                }
            }
        }

        if let reason = choice.finishReason {
            switch reason {
            case "tool_calls":
                if
                    let id = pendingToolId,
                    let name = pendingToolName
                {
                    // try to decode the full JSONValue
                    let parsedArgs: JSONValue
                    if
                        let data = pendingArgs.data(using: .utf8),
                        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
                    {
                        parsedArgs = decoded
                    } else {
                        // fall back to raw string
                        parsedArgs = .string(pendingArgs)
                    }
                    output.append(.toolCall(id: id, name: name, args: parsedArgs))
                }
                pendingToolName = nil
                pendingArgs = ""

            case "stop":
                output.append(.stop)

            default:
                break
            }
        }

        return output
    }
}
