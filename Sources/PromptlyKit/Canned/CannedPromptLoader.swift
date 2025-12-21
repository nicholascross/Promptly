import Foundation
import PromptlyKitUtils

public struct CannedPromptLoader {
    private let fileManager: FileManager
    private let baseDirectory: String

    public init(
        fileManager: FileManager = .default,
        baseDirectory: String = "~/.config/promptly/canned"
    ) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    public func load(name: String) throws -> String {
        let cannedURL = URL(fileURLWithPath: "\(baseDirectory)/\(name).txt".expandingTilde)
            .standardizedFileURL
        guard fileManager.fileExists(atPath: cannedURL.path) else {
            throw PromptSessionError.cannedPromptNotFound(cannedURL)
        }
        let data = try Data(contentsOf: cannedURL)
        return String(data: data, encoding: .utf8) ?? ""
    }
}
