import Foundation
@testable import PromptlyKit
import Testing

struct ToolCallDecodingTests {
    @Test
    func decodesWhenOnlyIdIsPresent() throws {
        let json = #"{"id":"abc","type":"function","function":{"name":"T","arguments":"{}"}}"#
        let call = try JSONDecoder().decode(ToolCall.self, from: Data(json.utf8))
        #expect(call.id == "abc")
        #expect(call.callId == "abc")
        #expect(call.function.name == "T")
        #expect(call.function.arguments == "{}")
    }

    @Test
    func decodesWhenOnlyCallIdIsPresent() throws {
        let json = #"{"call_id":"abc","type":"function","function":{"name":"T","arguments":"{}"}}"#
        let call = try JSONDecoder().decode(ToolCall.self, from: Data(json.utf8))
        #expect(call.id == "abc")
        #expect(call.callId == "abc")
    }

    @Test
    func decodesWhenBothIdAndCallIdArePresent() throws {
        let json = #"{"id":"tool_1","call_id":"call_1","type":"function","function":{"name":"T","arguments":"{}"}}"#
        let call = try JSONDecoder().decode(ToolCall.self, from: Data(json.utf8))
        #expect(call.id == "tool_1")
        #expect(call.callId == "call_1")
    }
}

