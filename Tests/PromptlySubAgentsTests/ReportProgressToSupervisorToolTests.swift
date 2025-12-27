import Foundation
@testable import PromptlySubAgents
import PromptlyKitUtils
import Testing

struct ReportProgressToSupervisorToolTests {
    @Test
    func logsProgressUpdatesAndPrefixesToolOutput() async throws {
        let fileManager = InMemoryFileManager()
        let logDirectoryURL = fileManager.currentDirectoryURL.appendingPathComponent("logs", isDirectory: true)
        let transcriptLogger = try SubAgentTranscriptLogger(
            logsDirectoryURL: logDirectoryURL,
            fileManager: fileManager
        )
        let outputRecorder = OutputRecorder()
        let tool = ReportProgressToSupervisorTool(
            agentName: "Progress Agent",
            toolOutput: { outputRecorder.append($0) },
            transcriptLogger: transcriptLogger
        )

        let arguments: JSONValue = .object([
            "status": .string("Working"),
            "summary": .string("Processing tasks")
        ])

        _ = try await tool.execute(arguments: arguments)
        await transcriptLogger.finish(status: "completed", error: nil)

        let outputs = outputRecorder.snapshot()
        #expect(outputs.count == 1)
        #expect(outputs.first?.hasPrefix("[sub-agent:Progress Agent]") == true)
        #expect(outputs.first?.contains("Working") == true)

        let logURL = URL(fileURLWithPath: transcriptLogger.logPath)
        let entries = try fileManager.loadJSONLines(from: logURL)
        let progressEntry = entries.first { entry in
            guard let object = objectValue(entry) else { return false }
            return stringValue(object["eventType"]) == "progress_update"
        }

        if let progressEntry,
           let object = objectValue(progressEntry),
           let dataObject = objectValue(object["data"]) {
            #expect(stringValue(dataObject["status"]) == "Working")
        } else {
            Issue.record("Expected progress_update entry.")
        }
    }
}

private final class OutputRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var outputs: [String] = []

    func append(_ output: String) {
        lock.lock()
        outputs.append(output)
        lock.unlock()
    }

    func snapshot() -> [String] {
        lock.lock()
        defer { lock.unlock() }
        return outputs
    }
}
