import Foundation

struct ProcessRunner: RunnableProcess {
    func run(
        executable: String,
        arguments: [String],
        currentDirectoryURL: URL?
    ) throws -> (exitCode: Int32, output: String) {
        let executablePath = try findExecutablePath(executable: executable)
        return try runProcess(
            executable: executablePath,
            arguments: arguments,
            currentDirectory: currentDirectoryURL
        )
    }

    private func findExecutablePath(executable: String) throws -> String {
        let (exitCode, output) = try runProcess(
            executable: "/usr/bin/which",
            arguments: [executable],
            currentDirectory: nil
        )

        guard exitCode == 0 else {
            throw ProcessRunnerError.executableNotFound(executable: executable)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        currentDirectory: URL?
    ) throws -> (exitCode: Int32, output: String) {
        print("Running: \(executable) \(arguments.joined(separator: " ")) in \(currentDirectory?.path ?? "$(pwd)")")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe
        try process.run()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(bytes: data, encoding: .utf8) ?? ""
        process.waitUntilExit()
        return (process.terminationStatus, output)
    }
}
