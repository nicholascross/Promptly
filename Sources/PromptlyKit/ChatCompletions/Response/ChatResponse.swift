import Foundation

struct ChatCompletionChunk: Decodable {
    let choices: [Choice]
}
