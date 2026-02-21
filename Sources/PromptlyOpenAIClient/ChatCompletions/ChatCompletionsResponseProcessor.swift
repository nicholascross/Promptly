import Foundation
import PromptlyKitUtils

public actor ChatCompletionsResponseProcessor {
    private let prefix = "data: "

    private var pendingToolCallsByIndex: [Int: PendingToolCall] = [:]
    private var pendingToolCallOrder: [Int] = []
    private var nextSyntheticToolCallIndex = 0
    private var lastUpdatedToolCallIndex: Int?

    public init() {}

    public func process(line: String) throws -> [Event] {
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
                let index = resolvedToolCallIndex(for: raw)

                if
                    let id = raw.id,
                    let name = raw.function.name,
                    let resolvedIndex = index
                {
                    if !pendingToolCallOrder.contains(resolvedIndex) {
                        pendingToolCallOrder.append(resolvedIndex)
                    }
                    pendingToolCallsByIndex[resolvedIndex] = PendingToolCall(
                        id: id,
                        name: name,
                        argumentsText: raw.function.arguments ?? ""
                    )
                    lastUpdatedToolCallIndex = resolvedIndex
                    continue
                }

                guard
                    let resolvedIndex = index,
                    var pendingToolCall = pendingToolCallsByIndex[resolvedIndex]
                else {
                    continue
                }

                pendingToolCall.argumentsText += raw.function.arguments ?? ""
                pendingToolCallsByIndex[resolvedIndex] = pendingToolCall
                lastUpdatedToolCallIndex = resolvedIndex
            }
        }

        if let reason = choice.finishReason {
            switch reason {
            case "tool_calls":
                for index in pendingToolCallOrder {
                    guard let pendingToolCall = pendingToolCallsByIndex[index] else {
                        continue
                    }

                    let parsedArgs: JSONValue
                    if
                        let data = pendingToolCall.argumentsText.data(using: .utf8),
                        let decoded = try? JSONDecoder().decode(JSONValue.self, from: data)
                    {
                        parsedArgs = decoded
                    } else {
                        parsedArgs = .string(pendingToolCall.argumentsText)
                    }
                    output.append(.toolCall(id: pendingToolCall.id, name: pendingToolCall.name, args: parsedArgs))
                }
                resetPendingToolCalls()

            case "stop":
                output.append(.stop)

            default:
                break
            }
        }

        return output
    }

    public func collectContent(from lines: AsyncThrowingStream<String, Error>) async throws -> String {
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
    struct PendingToolCall {
        let id: String
        let name: String
        var argumentsText: String
    }

    func resolvedToolCallIndex(for raw: RawToolCall) -> Int? {
        if let index = raw.index {
            return index
        }

        if
            let id = raw.id,
            let existingIndex = pendingToolCallsByIndex.first(where: { $0.value.id == id })?.key
        {
            return existingIndex
        }

        if raw.id != nil || raw.function.name != nil {
            defer { nextSyntheticToolCallIndex += 1 }
            return nextSyntheticToolCallIndex
        }

        if let lastUpdatedToolCallIndex {
            return lastUpdatedToolCallIndex
        }

        if pendingToolCallOrder.count == 1 {
            return pendingToolCallOrder[0]
        }

        return nil
    }

    func resetPendingToolCalls() {
        pendingToolCallsByIndex.removeAll(keepingCapacity: true)
        pendingToolCallOrder.removeAll(keepingCapacity: true)
        nextSyntheticToolCallIndex = 0
        lastUpdatedToolCallIndex = nil
    }

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
        let index: Int?
        let id: String?
        let function: FunctionDescriptor

        struct FunctionDescriptor: Decodable {
            let name: String?
            let arguments: String?
        }
    }
}
