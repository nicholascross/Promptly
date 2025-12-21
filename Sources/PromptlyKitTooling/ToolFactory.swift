import Foundation
import PromptlyKit
import PromptlyKitUtils

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
    /// Create executable tools from configuration, skipping opt-in tools unless explicitly enabled,
    /// wrap shell-command tools with log-slicing middleware, and filter by include/exclude lists.
    /// - Parameters:
    ///   - config: Promptly configuration for LLM access used by log slicing.
    ///   - includeTools: Substrings of tool names to explicitly enable opt-in tools.
    ///   - excludeTools: Substrings of tool names to explicitly disable matching tools.
    ///   - headLines: Number of lines to keep from the start of large outputs.
    ///   - tailLines: Number of lines to keep from the end of large outputs.
    ///   - sampleLines: Number of lines to sample for regex matches.
    ///   - toolOutput: Closure to receive streaming tool output.
    public func makeTools(
        config: Config,
        includeTools: [String] = [],
        excludeTools: [String] = [],
        headLines: Int = 250,
        tailLines: Int = 250,
        sampleLines: Int = 10,
        toolOutput: @Sendable @escaping (String) -> Void = { stream in fputs(stream, stdout); fflush(stdout) }
    ) throws -> [any ExecutableTool] {
        let defaultTools = try loadShellCommandConfig(
            configURL: toolsConfigURL,
            config: config,
            includeTools: includeTools,
            headLines: headLines,
            tailLines: tailLines,
            sampleLines: sampleLines,
            toolOutput: toolOutput
        )

        let localTools = try loadShellCommandConfig(
            configURL: localToolsConfigURL,
            config: config,
            includeTools: includeTools,
            headLines: headLines,
            tailLines: tailLines,
            sampleLines: sampleLines,
            toolOutput: toolOutput
        )

        // Merge the default tools with local tools, giving precedence to local tools.
        var tools = builtinTools(toolOutput: toolOutput)
        var toolNames = Set(tools.map { $0.name })
        for tool in localTools + defaultTools where !toolNames.contains(tool.name) {
            tools.append(tool)
            toolNames.insert(tool.name)
        }

        // Apply include/exclude filters to the merged tools
        var filtered = tools
        if !includeTools.isEmpty {
            filtered = filtered.filter { tool in
                includeTools.contains { include in tool.name.contains(include) }
            }
        }
        if !excludeTools.isEmpty {
            filtered = filtered.filter { tool in
                !excludeTools.contains { filter in tool.name.contains(filter) }
            }
        }
        return filtered
    }

    // Build the correct URL for tools.json, respecting --config-file override,
    // then local (./tools.json), then global (~/.config/promptly/tools.json).
    public func toolsConfigURL(_ override: String?) -> URL {
        if let path = override {
            return URL(fileURLWithPath: path).standardizedFileURL
        }

        let local = URL(
            fileURLWithPath: "tools.json",
            relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        ).standardizedFileURL

        if fileManager.fileExists(atPath: local.path) {
            return local
        }

        return URL(
            fileURLWithPath: ".config/promptly/tools.json",
            relativeTo: fileManager.homeDirectoryForCurrentUser
        ).standardizedFileURL
    }

    /// Load and merge shell command config entries from an optional override config file,
    /// falling back to local (./tools.json) then global (~/.config/promptly/tools.json).
    /// Returned entries give precedence to local entries with the same name.
    public func loadConfigEntries(overrideConfigFile override: String? = nil) throws -> [ShellCommandConfigEntry] {
        if let path = override {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let config = try decodeShellCommandConfig(from: url)
            return config.shellCommands
        }

        let defaultEntries: [ShellCommandConfigEntry] = {
            guard let config = try? decodeShellCommandConfig(from: toolsConfigURL) else { return [] }
            return config.shellCommands
        }()

        let localEntries: [ShellCommandConfigEntry] = {
            guard let config = try? decodeShellCommandConfig(from: localToolsConfigURL) else { return [] }
            return config.shellCommands
        }()

        let localIDs = Set(localEntries.map { $0.name })
        return localEntries + defaultEntries.filter { !localIDs.contains($0.name) }
    }

    /// Load and instantiate shell command tools from an allow list config file in JSON format.
    private func loadShellCommandConfig(
        configURL url: URL,
        config: Config,
        includeTools: [String],
        headLines: Int,
        tailLines: Int,
        sampleLines: Int,
        toolOutput: @Sendable @escaping (String) -> Void
    ) throws -> [any ExecutableTool] {
        guard fileManager.fileExists(atPath: url.path) else {
            return []
        }

        let commandConfig = try decodeShellCommandConfig(from: url)
        // Filter out opt-in tools unless explicitly included via includeTools substrings.
        let entries = commandConfig.shellCommands.filter { entry in
            guard entry.optIn == true else { return true }
            return includeTools.contains { include in entry.name.contains(include) }
        }

        return try entries.map { entry in
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
                return try LogSlicingTool(
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

    private func builtinTools(toolOutput: @Sendable @escaping (String) -> Void) -> [any ExecutableTool] {
        [
            ApplyPatchTool(
                rootDirectory: sandboxURL,
                output: toolOutput
            )
        ]
    }

    private var sandboxURL: URL {
        URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
    }

    /// Decode a shell-command config from JSON at the given URL.
    private func decodeShellCommandConfig(from url: URL) throws -> ShellCommandConfig {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(ShellCommandConfig.self, from: data)
    }
}

