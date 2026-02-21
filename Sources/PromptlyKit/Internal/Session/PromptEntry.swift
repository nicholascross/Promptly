import Foundation
import PromptlyOpenAIClient

enum PromptEntry: Sendable {
    case initial(messages: [ChatMessage])
    case resume(context: PromptContext, requestMessages: [ChatMessage])
    case toolCallResults(context: PromptContext, toolOutputs: [ToolCallOutput])
}
