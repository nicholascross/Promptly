import Foundation
@testable import PromptlyKit
import Testing
import PromptlyKitUtils

struct ChatMessageEncodingTests {
    @Test
    func toolRoleEncodesAsDeveloperAndUsesInputTextBlocks() throws {
        let message = ChatMessage(role: .tool, content: .text("{\"ok\":true}"))
        let encoded = try JSONEncoder().encode(message)
        let json = try JSONDecoder().decode([String: JSONValue].self, from: encoded)

        expectString(json["role"], equals: "developer")

        guard case let .array(blocksValue) = json["content"] else {
            Issue.record("Expected array content blocks")
            return
        }

        guard
            blocksValue.count == 1,
            case let .object(block) = blocksValue[0]
        else {
            Issue.record("Expected exactly one content block object")
            return
        }

        expectString(block["type"], equals: "input_text")
        expectString(block["text"], equals: "{\"ok\":true}")
    }

    @Test
    func systemRoleUsesInputTextBlocks() throws {
        let message = ChatMessage(role: .system, content: .text("hello"))
        let encoded = try JSONEncoder().encode(message)
        let json = try JSONDecoder().decode([String: JSONValue].self, from: encoded)

        expectString(json["role"], equals: "system")

        guard case let .array(blocksValue) = json["content"] else {
            Issue.record("Expected array content blocks")
            return
        }

        guard
            blocksValue.count == 1,
            case let .object(block) = blocksValue[0]
        else {
            Issue.record("Expected exactly one content block object")
            return
        }

        expectString(block["type"], equals: "input_text")
        expectString(block["text"], equals: "hello")
    }
}
