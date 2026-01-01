import ArgumentParser
import Foundation
import PromptlyKitUtils

/// `promptly canned add` - add a canned prompt
struct CannedAdd: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "add",
        abstract: "Add a canned prompt"
    )

    @Argument(help: "Name of the canned prompt (without .txt)")
    var name: String

    @Option(name: .customLong("content"), help: "Content to write into the canned prompt file")
    var content: String

    @Flag(name: .customLong("force"), help: "Overwrite an existing canned prompt")
    var force: Bool = false

    func run() throws {
        let fileManager: FileManagerProtocol = FileManager.default
        let baseDirectory = "~/.config/promptly/canned".expandingTilde
        let directoryURL = URL(fileURLWithPath: baseDirectory, isDirectory: true)
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true,
            attributes: nil
        )

        let fileURL = directoryURL.appendingPathComponent(normalizedPromptFileName(name))
        if fileManager.fileExists(atPath: fileURL.path), !force {
            FileHandle.standardError.write(Data("canned prompt \(name) already exists\n".utf8))
            throw ExitCode(2)
        }

        let data = Data(content.utf8)
        try fileManager.writeData(data, to: fileURL)
        print("Wrote canned prompt to \(fileURL.path)")
    }

    private func normalizedPromptFileName(_ name: String) -> String {
        if name.hasSuffix(".txt") {
            return name
        }
        return "\(name).txt"
    }
}
