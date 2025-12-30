import Foundation

extension PromptTranscriptRecorder {
    struct Configuration: Sendable {
        enum ToolOutputPolicy: Sendable {
            case include
            case tombstone
        }

        var toolOutputPolicy: ToolOutputPolicy

        init(toolOutputPolicy: ToolOutputPolicy = .tombstone) {
            self.toolOutputPolicy = toolOutputPolicy
        }
    }
}
