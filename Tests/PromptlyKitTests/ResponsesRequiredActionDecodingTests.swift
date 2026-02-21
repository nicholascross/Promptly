import Foundation
@testable import PromptlyKit
import PromptlyOpenAIClient
import Testing

struct ResponsesRequiredActionDecodingTests {
    @Test
    func toolCallsIncludesRequiredActionSubmitToolOutputs() throws {
        let json = """
        {
          "id": "r2",
          "status": "requires_action",
          "required_action": {
            "type": "submit_tool_outputs",
            "submit_tool_outputs": {
              "tool_calls": [
                {
                  "call_id": "call_1",
                  "type": "function",
                  "function": { "name": "Echo", "arguments": "{\\"a\\":1}" }
                }
              ]
            }
          }
        }
        """

        let response = try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
        let calls = response.toolCalls()
        #expect(calls.count == 1)
        #expect(calls.first?.callId == "call_1")
        #expect(calls.first?.function.name == "Echo")
    }

    @Test
    func combinedOutputTextUsesOutputTextField() throws {
        let json = """
        {
          "id": "r3",
          "status": "completed",
          "output_text": "Hello"
        }
        """

        let response = try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
        #expect(response.combinedOutputText() == "Hello")
    }
}

