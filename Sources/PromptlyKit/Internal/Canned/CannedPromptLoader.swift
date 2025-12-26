import Foundation
import PromptlyKitUtils

struct CannedPromptLoader {
    private let fileManager: FileManagerProtocol
    private let baseDirectory: String

    init(
        fileManager: FileManagerProtocol = FileManager.default,
        baseDirectory: String = "~/.config/promptly/canned"
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func load(name: String) throws -> String {
        let cannedURL = URL(fileURLWithPath: "\(baseDirectory)/\(name).txt".expandingTilde)
            .standardizedFileURL
        guard fileManager.fileExists(atPath: cannedURL.path) else {
            throw PromptSessionError.cannedPromptNotFound(cannedURL)
        }
        let data = try fileManager.readData(at: cannedURL)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
