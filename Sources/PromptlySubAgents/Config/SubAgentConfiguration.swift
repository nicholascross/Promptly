import Foundation
import PromptlyKit

struct SubAgentConfiguration: Sendable {
    let configuration: Config
    let definition: SubAgentDefinition
    let sourceURL: URL

    init(configuration: Config, definition: SubAgentDefinition, sourceURL: URL) {
        self.configuration = configuration
        self.definition = definition
        self.sourceURL = sourceURL
    }
}
