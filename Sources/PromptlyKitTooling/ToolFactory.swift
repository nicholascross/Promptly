import Foundation
import PromptlyAssets
import PromptlyKit
import PromptlyKitUtils

public struct ToolFactory {
    private let fileManager: FileManagerProtocol
    private let defaultToolsConfigURL: URL
    private let localToolsConfigURL: URL
    private let bundledToolsConfigURL: URL?

    public init(
        fileManager: FileManagerProtocol,
        toolsFileName: String = "tools.json",
        bundledResourceLoader: BundledResourceLoader = BundledResourceLoader()
    ) {
        self.fileManager = fileManager
        let normalizedToolsFileName = Self.normalizedToolsFileName(toolsFileName)
        self.defaultToolsConfigURL = Self.defaultToolsConfigURL(
            fileManager: fileManager,
            toolsFileName: normalizedToolsFileName
        )
        self.localToolsConfigURL = Self.localToolsConfigURL(
            fileManager: fileManager,
            toolsFileName: normalizedToolsFileName
        )
        self.bundledToolsConfigURL = Self.bundledToolsConfigURL(
            toolsFileName: normalizedToolsFileName,
            resourceLoader: bundledResourceLoader
        )
    }

    public init(
        fileManager: FileManagerProtocol,
        defaultToolsConfigURL: URL,
        localToolsConfigURL: URL,
        bundledToolsConfigURL: URL? = nil
    ) {
        self.fileManager = fileManager
        self.defaultToolsConfigURL = defaultToolsConfigURL.standardizedFileURL
        self.localToolsConfigURL = localToolsConfigURL.standardizedFileURL
        self.bundledToolsConfigURL = bundledToolsConfigURL?.standardizedFileURL
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
        let userTools = try loadShellCommandConfig(
            configURL: defaultToolsConfigURL,
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

        let bundledTools = try loadShellCommandConfig(
            configURL: bundledToolsConfigURL,
            config: config,
            includeTools: includeTools,
            headLines: headLines,
            tailLines: tailLines,
            sampleLines: sampleLines,
            toolOutput: toolOutput
        )

        // Merge the tools with precedence local, then user, then bundled.
        var tools = builtinTools(toolOutput: toolOutput)
        var toolNames = Set(tools.map { $0.name })
        for tool in localTools + userTools + bundledTools where !toolNames.contains(tool.name) {
            tools.append(tool)
            toolNames.insert(tool.name)
        }

        try validateIncludeFilters(
            includeTools,
            toolNames: tools.map { $0.name }
        )

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
    // then local (./tools.json), then user config (~/.config/promptly/tools.json).
    public func toolsConfigURL(_ override: String?) -> URL {
        if let path = override {
            return URL(fileURLWithPath: path).standardizedFileURL
        }
        if fileManager.fileExists(atPath: localToolsConfigURL.path) {
            return localToolsConfigURL
        }
        return defaultToolsConfigURL
    }

    /// Load and merge shell command config entries from an optional override config file.
    /// Returned entries give precedence to local entries, then user entries, then bundled entries.
    public func loadConfigEntries(overrideConfigFile override: String? = nil) throws -> [ShellCommandConfigEntry] {
        let entriesWithSources = try loadConfigEntriesWithSources(overrideConfigFile: override)
        return entriesWithSources.map { $0.entry }
    }

    /// Load and merge shell command config entries from an optional override config file.
    /// Returned entries give precedence to local entries, then user entries, then bundled entries.
    public func loadConfigEntriesWithSources(
        overrideConfigFile override: String? = nil
    ) throws -> [ToolConfigEntryWithSource] {
        if let path = override {
            let url = URL(fileURLWithPath: path).standardizedFileURL
            let config = try decodeShellCommandConfig(from: url)
            return config.shellCommands.map {
                ToolConfigEntryWithSource(entry: $0, source: .user)
            }
        }

        let bundledEntries = loadConfigEntriesIfPresent(at: bundledToolsConfigURL)
        let userEntries = loadConfigEntriesIfPresent(at: defaultToolsConfigURL)
        let localEntries = loadConfigEntriesIfPresent(at: localToolsConfigURL)

        var seenNames = Set<String>()
        var merged: [ToolConfigEntryWithSource] = []
        let sources: [(ToolConfigEntrySource, [ShellCommandConfigEntry])] = [
            (.local, localEntries),
            (.user, userEntries),
            (.bundled, bundledEntries)
        ]
        for (source, entries) in sources {
            for entry in entries where !seenNames.contains(entry.name) {
                merged.append(ToolConfigEntryWithSource(entry: entry, source: source))
                seenNames.insert(entry.name)
            }
        }

        return merged
    }

    /// Load and instantiate shell command tools from an allow list config file in JSON format.
    private func loadShellCommandConfig(
        configURL url: URL?,
        config: Config,
        includeTools: [String],
        headLines: Int,
        tailLines: Int,
        sampleLines: Int,
        toolOutput: @Sendable @escaping (String) -> Void
    ) throws -> [any ExecutableTool] {
        guard let url else {
            return []
        }
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

    public static func defaultToolsConfigURL(
        fileManager: FileManagerProtocol,
        toolsFileName: String
    ) -> URL {
        let normalizedToolsFileName = normalizedToolsFileName(toolsFileName)
        return URL(
            fileURLWithPath: ".config/promptly/\(normalizedToolsFileName)",
            relativeTo: fileManager.homeDirectoryForCurrentUser
        ).standardizedFileURL
    }

    public static func localToolsConfigURL(
        fileManager: FileManagerProtocol,
        toolsFileName: String
    ) -> URL {
        let normalizedToolsFileName = normalizedToolsFileName(toolsFileName)
        return URL(
            fileURLWithPath: normalizedToolsFileName,
            relativeTo: URL(fileURLWithPath: fileManager.currentDirectoryPath, isDirectory: true)
        ).standardizedFileURL
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

    private static func normalizedToolsFileName(_ toolsFileName: String) -> String {
        if toolsFileName.hasSuffix(".json") {
            return toolsFileName
        }
        return "\(toolsFileName).json"
    }

    public static func bundledToolsConfigURL(
        toolsFileName: String,
        resourceLoader: BundledResourceLoader = BundledResourceLoader()
    ) -> URL? {
        let normalizedToolsFileName = normalizedToolsFileName(toolsFileName)
        let url = URL(fileURLWithPath: normalizedToolsFileName)
        let name = url.deletingPathExtension().lastPathComponent
        let fileExtension = url.pathExtension.isEmpty ? "json" : url.pathExtension
        return resourceLoader.resourceURL(
            subdirectory: BundledDefaultAssetPaths.tools,
            name: name,
            fileExtension: fileExtension
        )
    }

    private func loadConfigEntriesIfPresent(
        at url: URL?
    ) -> [ShellCommandConfigEntry] {
        guard let url else {
            return []
        }
        guard fileManager.fileExists(atPath: url.path),
              let config = try? decodeShellCommandConfig(from: url) else {
            return []
        }
        return config.shellCommands
    }

    /// Decode a shell-command config from JSON at the given URL.
    private func decodeShellCommandConfig(from url: URL) throws -> ShellCommandConfig {
        let data = try fileManager.readData(at: url)
        return try JSONDecoder().decode(ShellCommandConfig.self, from: data)
    }

    private func validateIncludeFilters(
        _ includeTools: [String],
        toolNames: [String]
    ) throws {
        guard !includeTools.isEmpty else { return }

        for include in includeTools {
            guard toolNames.contains(where: { $0.contains(include) }) else {
                throw ToolFactoryError.includeFilterMatchesNoTools(filter: include)
            }
        }
    }
}
