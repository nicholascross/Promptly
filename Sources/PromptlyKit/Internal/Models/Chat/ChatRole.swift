import Foundation

enum ChatRole: String, Codable, Sendable {
    case system, user, assistant, tool
}
