import Foundation

public enum ProcessRunnerError: Error, LocalizedError {
    case executableNotFound(executable: String)
    case executionFailed(executable: String, exitCode: Int32, output: String)

    public var errorDescription: String? {
        switch self {
        case let .executableNotFound(executable):
            return "Executable '\(executable)' not found."
        case let .executionFailed(executable, exitCode, output):
            return "Execution of '\(executable)' failed with exit code \(exitCode): \(output)"
        }
    }
}
