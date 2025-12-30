import Foundation
import PromptlyKit
import PromptlyKitUtils

public struct PromptConsoleBuilder {
    public let input: PromptConsoleInput
    private let fileManager: FileManagerProtocol
    private let initialMessageComposer: InitialMessageComposer
    private let standardInputHandler: StandardInputHandler

    public init(
        input: PromptConsoleInput,
        fileManager: FileManagerProtocol = FileManager.default
    ) {
        let standardInputHandler = StandardInputHandler()
        let initialMessageComposer = InitialMessageComposer(
            cannedPromptLoader: CannedPromptLoader(fileManager: fileManager),
            standardInputHandler: standardInputHandler
        )
        self.init(
            input: input,
            fileManager: fileManager,
            initialMessageComposer: initialMessageComposer
        )
    }

    init(
        input: PromptConsoleInput,
        fileManager: FileManagerProtocol,
        initialMessageComposer: InitialMessageComposer
    ) {
        self.input = input
        self.fileManager = fileManager
        self.initialMessageComposer = initialMessageComposer
        self.standardInputHandler = initialMessageComposer.standardInputHandler
    }

    public func build() throws -> PromptConsoleRun {
        let configURL = try resolveConfigURL()
        let config = try Config.loadConfig(
            url: configURL,
            fileManager: fileManager,
            credentialSource: SystemCredentialSource()
        )
        let initialMessages = try initialMessageComposer.compose(
            cannedContexts: input.cannedContexts,
            contextArgument: input.contextArgument,
            explicitMessages: input.explicitMessages
        )

        return PromptConsoleRun(
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
            throw PromptError.missingConfiguration
        }
        return configURL
    }
}
