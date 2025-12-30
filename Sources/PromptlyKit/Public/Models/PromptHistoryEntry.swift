import PromptlyKitUtils

public enum PromptHistoryEntry: Sendable {
    case message(PromptMessage)
    case toolCall(id: String?, name: String, arguments: JSONValue)
    case toolOutput(toolCallId: String?, output: JSONValue)
}
