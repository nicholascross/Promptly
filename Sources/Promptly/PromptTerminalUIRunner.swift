import PromptlyKit
import PromptlyKitTooling
import PromptlyKitUtils
import TerminalUI

@MainActor
struct PromptTerminalUIRunner {
    let config: Config
    let toolFactory: ToolFactory
    let includeTools: [String]
    let excludeTools: [String]
    let modelOverride: String?
    let apiOverride: Config.API?
    let standardInputHandler: StandardInputHandler

    func run(initialMessages: [ChatMessage]) async throws {
        standardInputHandler.reopenIfNeeded()
        let controller = PromptlyTerminalUIController(
            config: config,
            toolFactory: toolFactory,
            includeTools: includeTools,
            excludeTools: excludeTools,
            modelOverride: modelOverride,
            initialMessages: initialMessages,
            apiOverride: apiOverride
        )
        try await controller.run()
    }
}
