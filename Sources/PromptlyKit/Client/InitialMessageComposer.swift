import Foundation
import PromptlyKitUtils

public struct InitialMessageComposer {
    let cannedPromptLoader: CannedPromptLoader
    let standardInputHandler: StandardInputHandler

    public init(
        cannedPromptLoader: CannedPromptLoader,
        standardInputHandler: StandardInputHandler
    ) {
        self.cannedPromptLoader = cannedPromptLoader
        self.standardInputHandler = standardInputHandler
    }

    public func compose(
        cannedContexts: [String],
        contextArgument: String?,
        explicitMessages: [ChatMessage]
    ) throws -> [ChatMessage] {
        var initialMessages: [ChatMessage] = []
        for name in cannedContexts {
            let canned = try cannedPromptLoader.load(name: name)
            initialMessages.append(.init(role: .system, content: .text(canned)))
        }
        if let ctx = contextArgument {
            initialMessages.append(.init(role: .system, content: .text(ctx)))
        }
        if let stdinMessage = standardInputHandler.readPipedInput() {
            initialMessages.append(.init(role: .user, content: .text(stdinMessage)))
        }
        initialMessages += explicitMessages
        return initialMessages
    }
}
