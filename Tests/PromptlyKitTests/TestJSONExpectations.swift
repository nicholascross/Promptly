import Foundation
@testable import PromptlyKit
import Testing

func expectString(_ value: JSONValue?, equals expected: String, sourceLocation: SourceLocation = #_sourceLocation) {
    guard case let .string(actual)? = value else {
        Issue.record("Expected string JSONValue", sourceLocation: sourceLocation)
        return
    }
    #expect(actual == expected, sourceLocation: sourceLocation)
}

func expectBool(_ value: JSONValue?, equals expected: Bool, sourceLocation: SourceLocation = #_sourceLocation) {
    guard case let .bool(actual)? = value else {
        Issue.record("Expected bool JSONValue", sourceLocation: sourceLocation)
        return
    }
    #expect(actual == expected, sourceLocation: sourceLocation)
}

func expectInteger(_ value: JSONValue?, equals expected: Int, sourceLocation: SourceLocation = #_sourceLocation) {
    guard case let .integer(actual)? = value else {
        Issue.record("Expected integer JSONValue", sourceLocation: sourceLocation)
        return
    }
    #expect(actual == expected, sourceLocation: sourceLocation)
}

