import Foundation

public struct ToolFactory {
    private let fileManager: FileManagerProtocol
    private let toolsFileName: String

    public init(fileManager: FileManagerProtocol = FileManager(), toolsFileName: String = "tools.json") {
        self.fileManager = fileManager
        if toolsFileName.hasSuffix(".json") {
            self.toolsFileName = toolsFileName
        } else {
            self.toolsFileName = "\(toolsFileName).json"
        }
    }

    /// Create executable tools from configuration and wrap shell-command tools with log-slicing middleware.
    /// - Parameters:
    ///   - config: Promptly configuration for LLM access used by log slicing.
    ///   - headLines: Number of lines to keep from the start of large outputs.
    ///   - tailLines: Number of lines to keep from the end of large outputs.
    public func makeTools(
        config: Config,
        headLines: Int = 250,
        tailLines: Int = 250,
        sampleLines: Int = 10,
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> [any ExecutableTool] {
        let defaultTools = try loadShellCommandConfig(
            configURL: toolsConfigURL,
            config: config,
            headLines: headLines,
            tailLines: tailLines,
            sampleLines: sampleLines,
            toolOutput: toolOutput
        )

        let localTools = try loadShellCommandConfig(
            configURL: localToolsConfigURL,
            config: config,
            headLines: headLines,
            tailLines: tailLines,
            sampleLines: sampleLines,
            toolOutput: toolOutput
        )

        // Merge the default tools with local tools, giving precedence to local tools.
        var tools = [any ExecutableTool]()
        var toolNames = Set<String>()
        for tool in localTools + defaultTools where !toolNames.contains(tool.name) {
            tools.append(tool)
            toolNames.insert(tool.name)
        }

        return tools
    }

    /// Load and instantiate shell command tools from an allow list config file in JSON format.
    /// Expected format in tools config file (default `tools.json`):
    /// {
    ///   "shellCommands": [
    ///     {
    ///       "name": "ls",
    ///       "description": "Recursively list a directory",
    ///       "executable": "/bin/ls",
    ///       "echoOutput": true,
    ///       "truncateOutput": true,
    ///       "argumentTemplate": [["-R", "{{path}}"]],
    ///       "parameters": { /* a valid JSONSchema */ }
    ///     },
    ///     ...
    ///   ]
    /// }
    private func loadShellCommandConfig(
        configURL url: URL,
        config: Config,
        headLines: Int,
        tailLines: Int,
        sampleLines: Int,
        toolOutput: @Sendable @escaping (String) -> Void
    ) throws -> [any ExecutableTool] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        let commandConfig = try JSONDecoder().decode(ShellCommandConfig.self, from: data)

        return commandConfig.shellCommands.map { entry in
            let shellTool = ShellCommandTool(
                name: entry.name,
                description: entry.description,
                executable: entry.executable,
                echoOutput: entry.echoOutput ?? false,
                truncateOutput: entry.truncateOutput ?? false,
                parameters: entry.parameters,
                argumentTemplate: entry.argumentTemplate,
                exclusiveArgumentTemplate: entry.exclusiveArgumentTemplate ?? false,
                sandboxURL: sandboxURL,
                fileManager: fileManager,
                toolOutput: toolOutput
            )

            if entry.truncateOutput ?? false {
                return LogSlicingTool(
                    wrapping: shellTool,
                    config: config,
                    headLines: headLines,
                    tailLines: tailLines,
                    sampleLines: sampleLines
                )
            }
            return shellTool
        }
    }

    private var localToolsConfigURL: URL {
        URL(
            fileURLWithPath: toolsFileName,
            relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        )
        .standardizedFileURL
    }

    private var toolsConfigURL: URL {
        URL(
            fileURLWithPath: ".config/promptly/\(toolsFileName)",
            relativeTo: fileManager.homeDirectoryForCurrentUser
        )
        .standardizedFileURL
    }

    private var sandboxURL: URL {
        URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    }
}
