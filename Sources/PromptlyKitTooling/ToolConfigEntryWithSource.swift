import PromptlyKit

public enum ToolConfigEntrySource: String, Sendable {
    case local
    case user
    case bundled
}

public struct ToolConfigEntryWithSource: Sendable {
    public let entry: ShellCommandConfigEntry
    public let source: ToolConfigEntrySource

    public init(entry: ShellCommandConfigEntry, source: ToolConfigEntrySource) {
        self.entry = entry
        self.source = source
    }
}
