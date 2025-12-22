import Foundation

/// How the model should choose to call tools.
enum ToolChoice: String, Codable {
    /// The model may call tools if needed.
    case auto
    /// The model will not call any tools.
    case none
}
