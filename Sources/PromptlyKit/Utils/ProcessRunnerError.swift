import Foundation

enum ProcessRunnerError: Error, LocalizedError {
    case executableNotFound(executable: String)
    case executionFailed(executable: String, exitCode: Int32, output: String)
    var errorDescription: String? {
        switch self {
        case let .executableNotFound(exec):
            return "Executable '\(exec)' not found."
        case let .executionFailed(exec, code, output):
            return "Execution of '\(exec)' failed with exit code \(code): \(output)"
        }
    }
}
