import Foundation

public extension Config {
    /// Install the default set of canned prompts into the global config directory.
    /// - Parameter overwrite: When true, existing canned prompts with the same name are replaced.
    static func setupCannedPrompts(overwrite: Bool) throws {
        let fileManager = FileManager()
        let cannedDir = fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/promptly/canned", isDirectory: true)
        try fileManager.createDirectory(at: cannedDir, withIntermediateDirectories: true)

        for (name, contents) in DefaultCannedPrompts.prompts {
            let fileURL = cannedDir.appendingPathComponent("\(name).txt", isDirectory: false)
            if fileManager.fileExists(atPath: fileURL.path), !overwrite {
                print("Skipped existing canned prompt at \(fileURL.path)")
                continue
            }
            try contents.write(to: fileURL, atomically: true, encoding: .utf8)
            print("Installed canned prompt to \(fileURL.path)")
        }
    }
}
