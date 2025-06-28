import Foundation

struct ToolSpec: Encodable {
    let type = "function"
    let function: Function
}
