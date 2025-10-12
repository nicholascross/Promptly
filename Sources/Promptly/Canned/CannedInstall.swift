import ArgumentParser
import Foundation
import PromptlyKit

/// `promptly canned install` — install default canned prompts
struct CannedInstall: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "install",
        abstract: "Install default canned prompts into the configuration directory"
    )

    @Flag(name: .customLong("overwrite"), help: "Overwrite canned prompts that already exist")
    var overwrite: Bool = false

    func run() throws {
        try Config.setupCannedPrompts(overwrite: overwrite)
    }
}
