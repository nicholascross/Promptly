import Foundation

public protocol FileManagerProtocol: Sendable {
    var currentDirectoryURL: URL { get }
    var currentDirectoryPath: String { get }
    var homeDirectoryForCurrentUser: URL { get }

    func fileExists(atPath path: String) -> Bool
    func contents(atPath path: String) -> Data?
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
    func removeItem(atPath path: String) throws
    func copyItem(atPath srcPath: String, toPath dstPath: String) throws
    func moveItem(atPath srcPath: String, toPath dstPath: String) throws
}

extension FileManager: FileManagerProtocol, @retroactive @unchecked Sendable {
    public var currentDirectoryURL: URL {
        return URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }
}
