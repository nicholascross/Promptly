import Foundation

public enum ToolFactoryError: Error, LocalizedError {
    case includeFilterMatchesNoTools(filter: String)

    public var errorDescription: String? {
        switch self {
        case let .includeFilterMatchesNoTools(filter):
            return "Include tools filter \"\(filter)\" did not match any available tools."
        }
    }
}
