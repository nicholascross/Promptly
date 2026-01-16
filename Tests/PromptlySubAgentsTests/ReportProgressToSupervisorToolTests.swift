import Foundation
@testable import PromptlySubAgents
import PromptlyKitUtils
import Testing

struct ReportProgressToSupervisorToolTests {
    @Test
    func prefixesToolOutput() async throws {
        let outputRecorder = OutputRecorder()
        let tool = ReportProgressToSupervisorTool(
            agentName: "Progress Agent",
            toolOutput: { outputRecorder.append($0) }
        )

        let arguments: JSONValue = .object([
            "status": .string("Working"),
            "summary": .string("Processing tasks")
        ])

        _ = try await tool.execute(arguments: arguments)

        let outputs = outputRecorder.snapshot()
        #expect(outputs.count == 1)
        #expect(outputs.first?.hasPrefix("[sub-agent:Progress Agent]") == true)
        #expect(outputs.first?.contains("Working") == true)

        #expect(outputs.first?.contains("Processing tasks") == true)
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
