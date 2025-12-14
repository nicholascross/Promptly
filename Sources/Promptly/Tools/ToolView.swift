import ArgumentParser
import Foundation
import PromptlyKit
import PromptlyKitTooling

/// `promptly tool view <id>` — show details for one tool
struct ToolView: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "view",
        abstract: "Show details for a specific tool"
    )

    @Argument(help: "ID of the tool to view")
    var id: String

    @OptionGroup
    var options: ToolConfigOptions

    func run() throws {
        let entries = try ToolFactory().loadConfigEntries(overrideConfigFile: options.configFile)
        guard let entry = entries.first(where: { $0.name == id }) else {
            FileHandle.standardError.write(Data("tool \(id) not found\n".utf8))
            throw ExitCode(3)
        }
        print("id: \(entry.name)")
        print("description: \(entry.description)")
        print("executable: \(entry.executable)")
        if let echoOuptut = entry.echoOutput { print("echoOutput: \(echoOuptut)") }
        if let truncateOutput = entry.truncateOutput { print("truncateOutput: \(truncateOutput)") }
        if let exclusiveArgumentTemplate = entry.exclusiveArgumentTemplate { print("exclusiveArgumentTemplate: \(exclusiveArgumentTemplate)") }
        if let optIn = entry.optIn { print("optIn: \(optIn)") }
        print("argumentTemplate: \(entry.argumentTemplate)")
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted
        let paramsData = try encoder.encode(entry.parameters)
        if let paramsJSON = String(data: paramsData, encoding: .utf8) {
            print("parameters: \(paramsJSON)")
        }
    }
}
