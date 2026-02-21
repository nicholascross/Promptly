import Foundation
import PromptlyKitUtils

extension ChatCompletionsResponseProcessor {
    public enum Event: Sendable {
        case content(String)
        case toolCall(id: String, name: String, args: JSONValue)
        case stop
    }
}
