import Foundation
import PromptlyKit

public extension Config {
    /// Install the default set of shell-command tools into the global config directory.
    /// - Parameter toolsName: Base name for the tools config file (without .json extension).
    static func setupTools(toolsName: String) throws {
        let config = DefaultShellCommandConfig.config
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let data = try encoder.encode(config)
        let fileManager = FileManager()
        let filename = toolsName.hasSuffix(".json") ? toolsName : "\(toolsName).json"
        let dirURL = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/promptly", isDirectory: true)
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)
        let fileURL = dirURL.appendingPathComponent(filename)
        try data.write(to: fileURL)
        print("Installed default tools to \(fileURL.path)")
    }
}
