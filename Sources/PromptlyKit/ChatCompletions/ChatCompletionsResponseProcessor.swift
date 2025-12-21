import Foundation
import PromptlyKitUtils

actor ChatCompletionsResponseProcessor {
    enum Event: Sendable {
        case content(String)
        case toolCall(id: String, name: String, args: JSONValue)
        case stop
    }

    private let prefix = "data: "

    private var pendingToolId: String?
    private var pendingToolName: String?
    private var pendingArgs = ""

    func process(line: String) throws -> [Event] {
        guard line.hasPrefix(prefix) else { return [] }

        let payload = String(line.dropFirst(prefix.count))
            .trimmingCharacters(in: .whitespacesAndNewlines)

        if payload == "[DONE]" {
            return []
        }

        let chunk = try JSONDecoder().decode(Chunk.self, from: Data(payload.utf8))
        guard let choice = chunk.choices.first else { return [] }

        var output: [Event] = []

        if let text = choice.delta.content, !text.isEmpty {
            output.append(.content(text))
        }

        if let calls = choice.delta.toolCalls {
            for raw in calls {
                if
                    let id = raw.id,
                    let name = raw.function.name
                {
                    pendingToolId = id
                    pendingToolName = name
                    pendingArgs = raw.function.arguments
                } else if pendingToolName != nil {
                    pendingArgs += raw.function.arguments
                }
            }
        }

        if let reason = choice.finishReason {
            switch reason {
            case "tool_calls":
                if let id = pendingToolId, let name = pendingToolName {
                    let parsedArgs: JSONValue
                    if
                        let data = pendingArgs.data(using: .utf8),
                        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
                    {
                        parsedArgs = decoded
                    } else {
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

    func collectContent(from lines: AsyncThrowingStream<String, Error>) async throws -> String {
        var content = ""
        for try await line in lines {
            for event in try process(line: line) {
                if case let .content(txt) = event {
                    content += txt
                }
            }
        }
        return content
    }
}

private extension ChatCompletionsResponseProcessor {
    struct Chunk: Decodable {
        let choices: [Choice]
    }

    struct Choice: Decodable {
        let delta: Delta
        let finishReason: String?

        enum CodingKeys: String, CodingKey {
            case delta
            case finishReason = "finish_reason"
        }
    }

    struct Delta: Decodable {
        let content: String?
        let toolCalls: [RawToolCall]?

        enum CodingKeys: String, CodingKey {
            case content
            case toolCalls = "tool_calls"
        }
    }

    struct RawToolCall: Decodable {
        let id: String?
        let function: FunctionDescriptor

        struct FunctionDescriptor: Decodable {
            let name: String?
            let arguments: String
        }
    }
}
