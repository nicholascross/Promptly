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

    public func makeTools() throws -> [any ExecutableTool] {
        let defaultTools = try loadShellCommandConfig(configURL: toolsConfigURL)
        let localTools = try loadShellCommandConfig(configURL: localToolsConfigURL)

        // Merge the default tools with local tools, giving precedence to local tools.
        var tools = [any ExecutableTool]()
        var toolNames = Set<String>()
        for tool in localTools + defaultTools where !toolNames.contains(tool.name) {
            tools.append(tool)
            toolNames.insert(tool.name)
        }
        return tools
    }

    /// Load and instantiate shell command tools from a allow list config file in JSON format.
    /// Expected format in tools config file (default `tools.json`):
    /// {
    ///   "shellCommands": [
    ///     {
    ///       "name": "ls",
    ///       "description": "Recursively list a directory",
    ///       "executable": "/bin/ls",
    ///       "argumentTemplate": [["-R", "{{path}}"]],
    ///       "parameters": { /* a valid JSONSchema */ }
    ///     },
    ///     ...
    ///   ]
    /// }
    private func loadShellCommandConfig(configURL url: URL) throws -> [any ExecutableTool] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let data = try Data(contentsOf: url)
        let commandConfig = try JSONDecoder().decode(ShellCommandConfig.self, from: data)

        return commandConfig.shellCommands.map { entry in
            ShellCommandTool(
                name: entry.name,
                description: entry.description,
                executable: entry.executable,
                parameters: entry.parameters,
                argumentTemplate: entry.argumentTemplate,
                sandboxURL: sandboxURL,
                fileManager: fileManager
            )
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
