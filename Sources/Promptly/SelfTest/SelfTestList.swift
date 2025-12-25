import ArgumentParser
import PromptlySelfTest

/// `promptly self-test list` - list available self test levels
struct SelfTestList: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "list",
        abstract: "List available self test levels"
    )

    func run() throws {
        let levels = SelfTestRunner.levels
        let levelColumnWidth = max(levels.map { $0.rawValue.count }.max() ?? 0, "Level".count)
        let headerLevel = "Level".padding(toLength: levelColumnWidth, withPad: " ", startingAt: 0)
        print("\(headerLevel)  Description")
        for level in levels {
            let name = level.rawValue.padding(toLength: levelColumnWidth, withPad: " ", startingAt: 0)
            print("\(name)  \(level.summary)")
        }
    }
}
