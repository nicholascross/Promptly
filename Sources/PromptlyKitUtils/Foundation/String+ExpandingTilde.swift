import Foundation

public extension String {
    var expandingTilde: String {
        guard hasPrefix("~") else { return self }
        return replacingOccurrences(
            of: "~",
            with: FileManager.default.homeDirectoryForCurrentUser.path,
            range: startIndex ..< index(after: startIndex)
        )
    }
}
