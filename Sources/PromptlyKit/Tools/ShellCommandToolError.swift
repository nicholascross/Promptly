import Foundation

enum ShellCommandToolError: Error, LocalizedError {
    case missingRequiredParameter(name: String)
    case missingOptionalParameter(name: String)
    case invalidSandboxPath(path: String)

    var errorDescription: String? {
        switch self {
        case let .missingRequiredParameter(key):
            return "Missing required parameter '\(key)' for command template."
        case let .missingOptionalParameter(key):
            return "Missing optional parameter '\(key)' for command template. This may not be an error, but the command may not function as expected."
        case let .invalidSandboxPath(path):
            return "Invalid sandbox path: '\(path)'. The path must be within the sandbox directory."
        }
    }
}
