import PromptlyKit
import PromptlyKitUtils

@MainActor
struct PromptTerminalUIRunner {
    let config: Config
    let toolProvider: (@escaping @Sendable (String) -> Void) throws -> [any ExecutableTool]
    let modelOverride: String?
    let apiOverride: Config.API?
    let standardInputHandler: StandardInputHandler

    func run(initialMessages: [PromptMessage]) async throws {
        standardInputHandler.reopenIfNeeded()
        let controller = PromptlyTerminalUIController(
            config: config,
            toolProvider: toolProvider,
            modelOverride: modelOverride,
            initialMessages: initialMessages,
            apiOverride: apiOverride
        )
        try await controller.run()
    }
}
