import Foundation
import PromptlyKit
import PromptlyKitUtils

struct InitialMessageComposer {
    let cannedPromptLoader: CannedPromptLoader
    let standardInputHandler: StandardInputHandler

    init(
        cannedPromptLoader: CannedPromptLoader,
        standardInputHandler: StandardInputHandler
    ) {
        self.cannedPromptLoader = cannedPromptLoader
        self.standardInputHandler = standardInputHandler
    }

    func compose(
        cannedContexts: [String],
        contextArgument: String?,
        explicitMessages: [PromptMessage]
    ) throws -> [PromptMessage] {
        var initialMessages: [PromptMessage] = []
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
