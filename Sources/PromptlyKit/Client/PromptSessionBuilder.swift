import Foundation
import PromptlyKitUtils

public struct PromptSessionBuilder {
    public let input: PromptSessionInput
    private let fileManager: FileManager
    private let cannedPromptLoader: CannedPromptLoader
    private let standardInputHandler: StandardInputHandler

    public init(
        input: PromptSessionInput,
        fileManager: FileManager = .default,
        cannedPromptLoader: CannedPromptLoader = CannedPromptLoader(),
        standardInputHandler: StandardInputHandler = StandardInputHandler()
    ) {
        self.input = input
        self.fileManager = fileManager
        self.cannedPromptLoader = cannedPromptLoader
        self.standardInputHandler = standardInputHandler
    }

    public func build() throws -> PromptSession {
        let configURL = try resolveConfigURL()
        let config = try Config.loadConfig(url: configURL)
        let initialMessages = try InitialMessageComposer(
            cannedPromptLoader: cannedPromptLoader,
            standardInputHandler: standardInputHandler
        ).compose(
            cannedContexts: input.cannedContexts,
            contextArgument: input.contextArgument,
            explicitMessages: input.explicitMessages
        )

        return PromptSession(
            config: config,
            toolsFileName: input.toolsFileName,
            includeTools: input.includeTools,
            excludeTools: input.excludeTools,
            modelOverride: input.modelOverride,
            apiOverride: input.apiOverride,
            standardInputHandler: standardInputHandler,
            initialMessages: initialMessages
        )
    }

    private func resolveConfigURL() throws -> URL {
        let configURL = URL(fileURLWithPath: input.configFilePath.expandingTilde).standardizedFileURL
        guard fileManager.fileExists(atPath: configURL.path) else {
            throw PrompterError.missingConfiguration
        }
        return configURL
    }
}
