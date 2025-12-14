import Foundation
@testable import PromptlyKit
import Testing

struct APIResponseOutputTextTests {
    @Test
    func combinedOutputTextSupportsTopLevelOutputTextItems() throws {
        let json = """
        {
          "id": "r1",
          "status": "completed",
          "output": [
            { "type": "output_text", "text": "Hello" }
          ]
        }
        """

        let response = try JSONDecoder().decode(APIResponse.self, from: Data(json.utf8))
        #expect(response.combinedOutputText() == "Hello")
    }
}

