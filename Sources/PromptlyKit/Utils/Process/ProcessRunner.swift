import Foundation

struct ProcessRunner: RunnableProcess {
    /// Handler for streaming output of tool calls (e.g., shell command stdout/stderr and prompt input).
    let toolOutputHandler: (String) -> Void

    /// Create a ProcessRunner.
    ///
    /// - Parameter toolOutputHandler: Handler for streaming output; defaults to standard output.
    init(toolOutputHandler: @escaping (String) -> Void = { stream in
        fputs(stream, stdout)
        fflush(stdout)
    }) {
        self.toolOutputHandler = toolOutputHandler
    }
    func run(
        executable: String,
        arguments: [String],
        currentDirectoryURL: URL?,
        streamOutput: Bool
    ) throws -> (exitCode: Int32, output: String) {
        let executablePath = try findExecutablePath(executable: executable)
        return try runProcess(
            executable: executablePath,
            arguments: arguments,
            currentDirectory: currentDirectoryURL,
            streamOutput: streamOutput
        )
    }

    private func findExecutablePath(executable: String) throws -> String {
        let (exitCode, output) = try runProcess(
            executable: "/usr/bin/which",
            arguments: [executable],
            currentDirectory: nil,
            streamOutput: false
        )

        guard exitCode == 0 else {
            throw ProcessRunnerError.executableNotFound(executable: executable)
        }

        return output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func runProcess(
        executable: String,
        arguments: [String],
        currentDirectory: URL?,
        streamOutput: Bool
    ) throws -> (exitCode: Int32, output: String) {
        // Report command invocation via the output handler instead of the global logger
        self.toolOutputHandler("Running: \(executable) \(arguments.joined(separator: " ")) in \(currentDirectory?.path ?? "$(pwd)")\n")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.currentDirectoryURL = currentDirectory
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        try process.run()

        let outputPipe: Pipe
        if streamOutput {
            outputPipe = Pipe()
            while process.isRunning {
                let data = pipe.fileHandleForReading.availableData
                if !data.isEmpty {
                    outputPipe.fileHandleForWriting.write(data)
                        if let output = String(data: data, encoding: .utf8) {
                            self.toolOutputHandler(output)
                    }
                } else {
                    break
                }
            }
            outputPipe.fileHandleForWriting.closeFile()
        } else {
            outputPipe = pipe
        }

        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        let output = String(bytes: data, encoding: .utf8) ?? ""
        process.waitUntilExit()
        return (process.terminationStatus, output)
    }
}
