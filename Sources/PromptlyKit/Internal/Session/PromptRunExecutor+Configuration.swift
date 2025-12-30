import Foundation

extension PromptRunExecutor {
    struct Configuration: Sendable {
        let maximumToolIterations: Int

        init(maximumToolIterations: Int = 8) {
            self.maximumToolIterations = max(0, maximumToolIterations)
        }
    }
}
