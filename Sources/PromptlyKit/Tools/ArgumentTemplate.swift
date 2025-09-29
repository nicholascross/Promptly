@preconcurrency import SwiftTokenizer

actor ArgumentTemplate {
    private let tokens: [ArgumentTemplateToken]

    private static let lexer = Lexer<ArgumentTemplateToken> {
        TokenRule(/\{\{([^}]+)\}\}/) { match in
            ArgumentTemplateToken.argument(String(match.output.1))
        }
        TokenRule(/\{\(([^)]+)\)\}/) { match in
            ArgumentTemplateToken.path(String(match.output.1))
        }
        TokenRule(/[^{}()]+/) { match in
            ArgumentTemplateToken.other(String(match.output))
        }
        TokenRule(/./) { match in
            ArgumentTemplateToken.other(String(match.output))
        }
    }

    init(string: String) throws {
        tokens = try Self.lexer.scan(string)
    }

    func resolveArguments(
        arguments: JSONValue,
        validateRequiredParameters: (String) throws -> Void,
        validateSandboxPath: (String) throws -> Void
    ) throws -> String {
        let rawArguments = try arguments.decoded([String: JSONValue].self)

        return try tokens.compactMap { token in
            switch token {
            case let .argument(argument):
                guard let value = rawArguments[argument] else {
                    try validateRequiredParameters(argument)
                    throw ShellCommandToolError.missingOptionalParameter(name: argument)
                }
                return value.description
            case let .path(path):
                guard let value = rawArguments[path] else {
                    try validateRequiredParameters(path)
                    throw ShellCommandToolError.missingOptionalParameter(name: path)
                }
                try validateSandboxPath(value.description)
                return value.description
            case let .other(other):
                return other
            }
        }.joined()
    }
}
