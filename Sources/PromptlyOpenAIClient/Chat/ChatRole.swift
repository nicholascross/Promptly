import Foundation

public enum ChatRole: String, Codable, Sendable {
    case system, user, assistant, tool
}
