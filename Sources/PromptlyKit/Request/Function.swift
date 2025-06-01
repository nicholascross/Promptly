import Foundation

struct Function: Encodable {
    let name: String
    let description: String
    let parameters: JSONValue
}
