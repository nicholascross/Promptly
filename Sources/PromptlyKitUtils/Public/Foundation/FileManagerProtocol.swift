import Foundation

public protocol FileManagerProtocol: Sendable {
    var currentDirectoryURL: URL { get }
    var currentDirectoryPath: String { get }
    var homeDirectoryForCurrentUser: URL { get }

    func fileExists(atPath path: String) -> Bool
    func directoryExists(atPath path: String) -> Bool
    func contents(atPath path: String) -> Data?
    func readData(at url: URL) throws -> Data
    func writeData(_ data: Data, to url: URL) throws
    func appendData(_ data: Data, to url: URL) throws
    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys keys: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL]
    func createDirectory(
        at url: URL,
        withIntermediateDirectories: Bool,
        attributes: [FileAttributeKey: Any]?
    ) throws
    func createFile(atPath path: String, contents data: Data?, attributes attr: [FileAttributeKey: Any]?) -> Bool
    func removeItem(atPath path: String) throws
    func copyItem(atPath srcPath: String, toPath dstPath: String) throws
    func moveItem(atPath srcPath: String, toPath dstPath: String) throws
}

extension FileManager: FileManagerProtocol, @retroactive @unchecked Sendable {
    public var currentDirectoryURL: URL {
        return URL(fileURLWithPath: currentDirectoryPath, isDirectory: true)
    }

    public func directoryExists(atPath path: String) -> Bool {
        var isDirectory: ObjCBool = false
        guard fileExists(atPath: path, isDirectory: &isDirectory) else {
            return false
        }
        return isDirectory.boolValue
    }

    public func readData(at url: URL) throws -> Data {
        try Data(contentsOf: url)
    }

    public func writeData(_ data: Data, to url: URL) throws {
        try data.write(to: url)
    }

    public func appendData(_ data: Data, to url: URL) throws {
        if !fileExists(atPath: url.path) {
            createFile(atPath: url.path, contents: nil, attributes: nil)
        }
        let handle = try FileHandle(forWritingTo: url)
        defer {
            try? handle.close()
        }
        try handle.seekToEnd()
        handle.write(data)
    }
}
