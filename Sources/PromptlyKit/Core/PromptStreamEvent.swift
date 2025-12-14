import Foundation

/// Provider-neutral events produced while running a prompt session.
///
/// This type is intended to be stable for reuse across different clients (command line, UI, tests),
/// while provider-specific request/response DTOs remain strongly typed and internal to adapters.
public enum PromptStreamEvent: Sendable {
    /// A streaming text fragment from the assistant.
    case assistantTextDelta(String)

    /// The model requested a tool call.
    case toolCallRequested(id: String?, name: String, arguments: JSONValue)

    /// A tool finished executing and produced output.
    case toolCallCompleted(id: String?, name: String, output: JSONValue)
}

