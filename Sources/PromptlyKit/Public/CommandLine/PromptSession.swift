import PromptlyKitUtils

public struct PromptSession {
    public let config: Config
    public let toolsFileName: String
    public let includeTools: [String]
    public let excludeTools: [String]
    public let modelOverride: String?
    public let apiOverride: Config.API?
    public let standardInputHandler: StandardInputHandler
    public let initialMessages: [PromptMessage]

    public init(
        config: Config,
        toolsFileName: String,
        includeTools: [String],
        excludeTools: [String],
        modelOverride: String?,
        apiOverride: Config.API?,
        standardInputHandler: StandardInputHandler,
        initialMessages: [PromptMessage]
    ) {
        self.config = config
        self.toolsFileName = toolsFileName
        self.includeTools = includeTools
        self.excludeTools = excludeTools
        self.modelOverride = modelOverride
        self.apiOverride = apiOverride
        self.standardInputHandler = standardInputHandler
        self.initialMessages = initialMessages
    }
}
