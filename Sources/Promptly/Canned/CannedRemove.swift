import ArgumentParser
import Foundation
import PromptlyKitUtils

/// `promptly canned remove` - remove a canned prompt
struct CannedRemove: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "remove",
        abstract: "Remove a canned prompt"
    )

    @Argument(help: "Name of the canned prompt to remove")
    var name: String

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let baseDirectory = "~/.config/promptly/canned".expandingTilde
        let directoryURL = URL(fileURLWithPath: baseDirectory, isDirectory: true)
        let fileURL = directoryURL.appendingPathComponent(normalizedPromptFileName(name))

        guard fileManager.fileExists(atPath: fileURL.path) else {
            FileHandle.standardError.write(Data("canned prompt \(name) not found\n".utf8))
            throw ExitCode(3)
        }

        try fileManager.removeItem(atPath: fileURL.path)
    }

    private func normalizedPromptFileName(_ name: String) -> String {
        if name.hasSuffix(".txt") {
            return name
        }
        return "\(name).txt"
    }
}
