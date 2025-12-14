import Foundation
import PromptlyKit

/// A middleware tool that wraps a shell command tool to slice large logs,
/// asking the language model to suggest regex patterns based on the beginning and end of the log,
/// then filtering the omitted portion locally with those patterns.
public struct LogSlicingTool: ExecutableTool {
    public let name: String
    public let description: String
    public let parameters: JSONSchema

    private let wrapped: any ExecutableTool
    private let headLines: Int
    private let tailLines: Int
    private let sampleLines: Int

    private let suggestionService: SuggestionService

    public init(
        wrapping tool: any ExecutableTool,
        config: Config,
        headLines: Int,
        tailLines: Int,
        sampleLines: Int
    ) throws {
        wrapped = tool
        name = tool.name
        description = tool.description
        parameters = tool.parameters
        self.headLines = headLines
        self.tailLines = tailLines
        self.sampleLines = sampleLines
        suggestionService = try SuggestionService(config: config)
    }

    public func execute(arguments: JSONValue) async throws -> JSONValue {
        let result = try await wrapped.execute(arguments: arguments)
        guard
            let context = parseResult(result),
            context.lines.count > headLines + tailLines
        else {
            return result
        }

        let (head, tail, omitted) = splitLines(lines: context.lines)

        let regexPatterns = try await suggestionService.suggestPatterns(
            head: Array(head.prefix(sampleLines)),
            tail: Array(tail.suffix(sampleLines)),
            truncatedSample: omitted.sampleRandomLines(sampleLines),
            toolName: wrapped.name,
            toolDescription: wrapped.description,
            arguments: arguments
        )

        let filteredLines = omitted.apply(patterns: regexPatterns)
        let condensed = makeCondensedOutput(head: head, filtered: filteredLines, tail: tail)

        return makeResult(
            exitCode: context.exitCode,
            condensedOutput: condensed,
            omittedCount: omitted.count - filteredLines.count,
            patterns: regexPatterns
        )
    }

    private func parseResult(_ result: JSONValue) -> (exitCode: JSONValue, lines: [String])? {
        guard
            case let .object(dict) = result,
            let exitCode = dict["exitCode"],
            case let .string(output) = dict["output"]
        else {
            return nil
        }

        let lines = output
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)

        return (exitCode, lines)
    }

    private func splitLines(lines: [String]) -> (head: [String], tail: [String], omitted: [String]) {
        let head = Array(lines.prefix(headLines))
        let tail = Array(lines.suffix(tailLines))
        let omitted = Array(lines.dropFirst(headLines).dropLast(tailLines))
        return (head, tail, omitted)
    }

    private func makeCondensedOutput(head: [String], filtered: [String], tail: [String]) -> String {
        [head, filtered, tail].flatMap { $0 }.joined(separator: "\n")
    }

    private func makeResult(
        exitCode: JSONValue,
        condensedOutput: String,
        omittedCount: Int,
        patterns: [String]
    ) -> JSONValue {
        .object([
            "exitCode": exitCode,
            "output": .string(condensedOutput),
            "skippedLines": .number(Double(omittedCount)),
            "regex": .array(patterns.map { .string($0) })
        ])
    }
}

private extension [String] {
    func apply(patterns: [String]) -> [String] {
        var matches = [String]()
        for pattern in patterns {
            let regex: Regex<Substring>
            do {
                regex = try Regex(pattern)
            } catch {
                continue
            }

            for string in self where string.firstMatch(of: regex) != nil {
                matches.append(string)
            }
        }
        return matches
    }
}

private extension Collection where Index == Int {
    func sampleRandomLines(_ count: Int) -> [Element] {
        guard !isEmpty, count > 0 else { return [] }
        return (0 ..< count)
            .map { Int.random(in: $0 ..< self.count) }
            .map { self[$0] }
    }
}
