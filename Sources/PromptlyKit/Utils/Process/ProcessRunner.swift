import Foundation

struct ProcessRunner: RunnableProcess, Sendable {
    /// Handler for streaming output of tool calls (e.g., shell command stdout/stderr and prompt input).
    let toolOutputHandler: @Sendable (String) -> Void

    /// Create a ProcessRunner.
    ///
    /// - Parameter toolOutputHandler: Handler for streaming output; defaults to standard output.
    init(toolOutputHandler: @escaping @Sendable (String) -> Void = { stream in
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
    ) async throws -> (exitCode: Int32, output: String) {
        let executablePath = try await findExecutablePath(executable: executable)
        return try await runProcess(
            executable: executablePath,
            arguments: arguments,
            currentDirectory: currentDirectoryURL,
            streamOutput: streamOutput
        )
    }

    private func findExecutablePath(executable: String) async throws -> String {
        let (exitCode, output) = try await runProcess(
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
    ) async throws -> (exitCode: Int32, output: String) {
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

        let readHandle = pipe.fileHandleForReading
        let outputData = DataBuffer()

        if streamOutput {
            readHandle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                } else {
                    Task {
                        await outputData.append(data)
                    }
                    if let string = String(data: data, encoding: .utf8) {
                        self.toolOutputHandler(string)
                    }
                }
            }
        }

        process.waitUntilExit()

        if streamOutput {
            readHandle.readabilityHandler = nil
            let remaining = readHandle.readDataToEndOfFile()
            if !remaining.isEmpty {
                Task {
                    await outputData.append(remaining)
                }
                if let string = String(data: remaining, encoding: .utf8) {
                    self.toolOutputHandler(string)
                }
            }
            let output = String(data: await outputData.snapshot(), encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        } else {
            let data = readHandle.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8) ?? ""
            return (process.terminationStatus, output)
        }
    }
}

private actor DataBuffer {
    private var data = Data()
    func append(_ chunk: Data) { data.append(chunk) }
    func snapshot() -> Data { data }
}
