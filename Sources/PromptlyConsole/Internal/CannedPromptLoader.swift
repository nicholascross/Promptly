import Foundation
import PromptlyAssets
import PromptlyKitUtils

struct CannedPromptLoader {
    private let fileManager: FileManagerProtocol
    private let baseDirectory: String
    private let bundledResourceLoader: BundledResourceLoader

    init(
        fileManager: FileManagerProtocol = FileManager.default,
        baseDirectory: String = "~/.config/promptly/canned",
        bundledResourceLoader: BundledResourceLoader = BundledResourceLoader()
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
        self.bundledResourceLoader = bundledResourceLoader
    }

    func load(name: String) throws -> String {
        let cannedURL = URL(fileURLWithPath: "\(baseDirectory)/\(name).txt".expandingTilde)
            .standardizedFileURL
        if fileManager.fileExists(atPath: cannedURL.path) {
            let data = try fileManager.readData(at: cannedURL)
            return String(data: data, encoding: .utf8) ?? ""
        }

        if let bundled = bundledResourceLoader.loadTextResource(
            subdirectory: BundledDefaultAssetPaths.cannedPrompts,
            name: name,
            fileExtension: "txt"
        ) {
            return bundled
        }

        throw PromptConsoleError.cannedPromptNotFound(cannedURL)
    }
}
