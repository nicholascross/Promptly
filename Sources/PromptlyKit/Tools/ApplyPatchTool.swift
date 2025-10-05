import Foundation
import PatchApplyKit

public struct ApplyPatchTool: ExecutableTool, Sendable {
    public let name = "ApplyPatch"
    public let description = #"""
Apply a unified diff patch to the current workspace. Provide plain text wrapped by `*** Begin Patch` and `*** End Patch`, optionally prefixed with headers such as `*** Update File: path/to/file`. For each file, include paired `--- old` / `+++ new` lines (use `/dev/null` for adds or deletes), any metadata lines like `new file mode 100644`, and one or more `@@` hunks that spell out context, `-` deletions, and `+` insertions. Omit binary payload markers such as `Binary files` or `GIT binary patch`.

Patch format overview:
1. Start with `*** Begin Patch` on its own line; everything until `*** End Patch` belongs to the patch body.
2. Optionally add descriptive headers beginning with `*** ` (for example, `*** Update File: src/main.swift`). The first header becomes the patch title.
3. Supply `--- old` / `+++ new` path lines, using `/dev/null` for creations or deletions. When omitted for simple directives, the parser falls back to the preceding `*** … File:` header, but explicit path lines remain the most portable.
4. Emit Git-style metadata lines as needed: `new file mode …`, `rename from …`, `rename to …`, `copy from …`, `copy to …`, `similarity index …`, `index …`.
5. Include one or more hunks for textual modifications. Each hunk starts with `@@ -oldStart[,len] +newStart[,len] @@` and is followed by body lines prefixed with a space (context), `-` (deletion), or `+` (addition). Add `\ No newline at end of file` immediately after a changed line that lacks a trailing newline.
6. Repeat headers, path lines, metadata, and hunks for additional directives. Moves and copies may omit hunks when content is unchanged; use `rename from` / `rename to` or `copy from` / `copy to` metadata to express the operation.
7. Close the payload with `*** End Patch`.

When moving or renaming files, pair the metadata (`rename from …` / `rename to …`) with the appropriate path lines. To copy, use `copy from …` / `copy to …` metadata (and hunks if content diverges). To delete, set the added path to `/dev/null`, optionally prefacing the block with `*** Delete File: path`. Copies, moves, deletions, and edits can be combined within one patch body.
"""#
    public let parameters: JSONSchema = .object(
        requiredProperties: [
            "patch": .string(
                minLength: 1,
                maxLength: nil,
                pattern: nil,
                format: nil,
                description: "Unified diff text wrapped by *** Begin Patch / *** End Patch sentinels."
            )
        ],
        optionalProperties: [
            "contextTolerance": .integer(
                minimum: 0,
                maximum: nil,
                description: "Number of mismatched context lines to forgive per hunk."
            ),
            "whitespace": .string(
                minLength: 1,
                maxLength: nil,
                pattern: nil,
                format: nil,
                description: "Whitespace matching mode: `exact` or `ignoreAll`."
            )
        ],
        description: "Apply a multi-file patch following Git's unified diff format."
    )

    private let rootPath: String
    private let output: @Sendable (String) -> Void

    public init(rootDirectory: URL, output: @Sendable @escaping (String) -> Void) {
        rootPath = rootDirectory
            .standardizedFileURL
            .resolvingSymlinksInPath()
            .path
        self.output = output
    }

    public func execute(arguments: JSONValue) async throws -> JSONValue {
        let request = try arguments.decoded(Request.self)
        guard request.hasContent else {
            throw ToolError.emptyPatch
        }

        output("Applying patch:\n\(request.patch)\n\n")

        let tokenizer = PatchTokenizer()
        let tokens = try tokenizer.tokenize(request.patch)
        let parser = PatchParser()
        let plan = try parser.parse(tokens: tokens)
        try PatchValidator().validate(plan)

        let sandbox = SandboxedFileSystem(rootPath: rootPath)
        let applicator = PatchApplicator(
            fileSystem: sandbox,
            configuration: request.configuration
        )
        try applicator.apply(plan)

        let summary = plan.directives.map { directive -> JSONValue in
            let path = directive.newPath ?? directive.oldPath ?? ""
            return .object([
                "operation": .string(directive.operation.identifier),
                "path": .string(path)
            ])
        }

        return .object([
            "applied": .bool(true),
            "directives": .array(summary)
        ])
    }
}

private extension ApplyPatchTool {
    struct Request: Decodable {
        let patch: String
        let contextTolerance: Int?
        let whitespace: String?

        var configuration: PatchApplicator.Configuration {
            PatchApplicator.Configuration(
                whitespace: whitespaceMode,
                contextTolerance: max(0, contextTolerance ?? 0)
            )
        }

        var whitespaceMode: PatchApplicator.WhitespaceMode {
            guard let whitespace else { return .exact }
            switch whitespace.lowercased() {
            case "ignoreall", "ignore_all", "ignore-all":
                return .ignoreAll
            default:
                return .exact
            }
        }

        var hasContent: Bool {
            !patch.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }

        enum CodingKeys: String, CodingKey {
            case patch
            case contextTolerance = "contextTolerance"
            case contextToleranceSnake = "context_tolerance"
            case whitespace
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            patch = try container.decode(String.self, forKey: .patch)
            let camel = try container.decodeIfPresent(Int.self, forKey: .contextTolerance)
            let snake = try container.decodeIfPresent(Int.self, forKey: .contextToleranceSnake)
            contextTolerance = camel ?? snake
            whitespace = try container.decodeIfPresent(String.self, forKey: .whitespace)
        }
    }

    enum ToolError: Error, LocalizedError {
        case emptyPatch

        var errorDescription: String? {
            switch self {
            case .emptyPatch:
                return "Patch text is empty; nothing to apply."
            }
        }
    }
}

private extension PatchOperation {
    var identifier: String {
        switch self {
        case .add:
            return "add"
        case .delete:
            return "delete"
        case .modify:
            return "modify"
        case .rename:
            return "rename"
        case .copy:
            return "copy"
        }
    }
}
