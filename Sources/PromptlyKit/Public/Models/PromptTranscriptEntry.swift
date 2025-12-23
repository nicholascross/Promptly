import Foundation
import PromptlyKitUtils

public enum PromptTranscriptEntry: Sendable {
    case assistant(message: String)
    case toolCall(id: String?, name: String, arguments: JSONValue?, output: JSONValue?)
}
