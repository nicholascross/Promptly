public struct PromptSessionInput {
    public let configFilePath: String
    public let toolsFileName: String
    public let includeTools: [String]
    public let excludeTools: [String]
    public let contextArgument: String?
    public let cannedContexts: [String]
    public let explicitMessages: [PromptMessage]
    public let modelOverride: String?
    public let apiOverride: Config.API?

    public init(
        configFilePath: String,
        toolsFileName: String,
        includeTools: [String],
        excludeTools: [String],
        contextArgument: String?,
        cannedContexts: [String],
        explicitMessages: [PromptMessage],
        modelOverride: String?,
        apiOverride: Config.API?
    ) {
        self.configFilePath = configFilePath
        self.toolsFileName = toolsFileName
        self.includeTools = includeTools
        self.excludeTools = excludeTools
        self.contextArgument = contextArgument
        self.cannedContexts = cannedContexts
        self.explicitMessages = explicitMessages
        self.modelOverride = modelOverride
        self.apiOverride = apiOverride
    }
}
