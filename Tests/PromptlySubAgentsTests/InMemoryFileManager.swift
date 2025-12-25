import Foundation
import PromptlyKitUtils

final class InMemoryFileManager: FileManagerProtocol, @unchecked Sendable {
    let currentDirectoryURL: URL
    let currentDirectoryPath: String
    let homeDirectoryForCurrentUser: URL

    private var files: [String: Data] = [:]
    private var directories: Set<String>

    init(rootPath: String = "/virtual") {
        let normalizedRoot = rootPath.hasPrefix("/") ? rootPath : "/" + rootPath
        currentDirectoryPath = normalizedRoot
        currentDirectoryURL = URL(fileURLWithPath: normalizedRoot, isDirectory: true)
        homeDirectoryForCurrentUser = currentDirectoryURL.appendingPathComponent("home", isDirectory: true)
        directories = [normalizedRoot, homeDirectoryForCurrentUser.path]
    }

    func fileExists(atPath path: String) -> Bool {
        files[path] != nil || directories.contains(path)
    }

    func directoryExists(atPath path: String) -> Bool {
        directories.contains(path)
    }

    func contents(atPath path: String) -> Data? {
        files[path]
    }

    func readData(at url: URL) throws -> Data {
        if let data = files[url.path] {
            return data
        }
        throw CocoaError(.fileReadNoSuchFile)
    }

    func writeData(_ data: Data, to url: URL) throws {
        ensureParentDirectoryExists(for: url)
        files[url.path] = data
    }

    func appendData(_ data: Data, to url: URL) throws {
        ensureParentDirectoryExists(for: url)
        var existing = files[url.path] ?? Data()
        existing.append(data)
        files[url.path] = existing
    }

    func contentsOfDirectory(
        at url: URL,
        includingPropertiesForKeys _: [URLResourceKey]?,
        options: FileManager.DirectoryEnumerationOptions
    ) throws -> [URL] {
        let parentPath = url.path
        guard directories.contains(parentPath) else {
            throw CocoaError(.fileReadNoSuchFile)
        }

        var results: [URL] = []
        for (path, _) in files where isDirectChild(path: path, parentPath: parentPath) {
            let entryURL = URL(fileURLWithPath: path)
            if shouldInclude(url: entryURL, options: options) {
                results.append(entryURL)
            }
        }
        for path in directories where isDirectChild(path: path, parentPath: parentPath) {
            let entryURL = URL(fileURLWithPath: path)
            if shouldInclude(url: entryURL, options: options) {
                results.append(entryURL)
            }
        }
        return results
    }

    func createDirectory(
        at url: URL,
        withIntermediateDirectories: Bool,
        attributes _: [FileAttributeKey: Any]?
    ) throws {
        if withIntermediateDirectories {
            var current = ""
            for component in url.path.split(separator: "/") {
                current.append("/\(component)")
                directories.insert(current)
            }
        } else {
            directories.insert(url.path)
        }
    }

    func createFile(atPath path: String, contents data: Data?, attributes _: [FileAttributeKey: Any]?) -> Bool {
        ensureParentDirectoryExists(path: path)
        files[path] = data ?? Data()
        return true
    }

    func removeItem(atPath path: String) throws {
        files.removeValue(forKey: path)
        directories.remove(path)
        let prefix = path.hasSuffix("/") ? path : "\(path)/"
        files.keys.filter { $0.hasPrefix(prefix) }.forEach { files.removeValue(forKey: $0) }
        directories.filter { $0.hasPrefix(prefix) }.forEach { directories.remove($0) }
    }

    func copyItem(atPath srcPath: String, toPath dstPath: String) throws {
        guard let data = files[srcPath] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        ensureParentDirectoryExists(path: dstPath)
        files[dstPath] = data
    }

    func moveItem(atPath srcPath: String, toPath dstPath: String) throws {
        guard let data = files[srcPath] else {
            throw CocoaError(.fileReadNoSuchFile)
        }
        ensureParentDirectoryExists(path: dstPath)
        files[dstPath] = data
        files.removeValue(forKey: srcPath)
    }

    private func ensureParentDirectoryExists(for url: URL) {
        ensureParentDirectoryExists(path: url.path)
    }

    private func ensureParentDirectoryExists(path: String) {
        let parentPath = URL(fileURLWithPath: path).deletingLastPathComponent().path
        if !directories.contains(parentPath) {
            try? createDirectory(
                at: URL(fileURLWithPath: parentPath, isDirectory: true),
                withIntermediateDirectories: true,
                attributes: nil
            )
        }
    }

    private func isDirectChild(path: String, parentPath: String) -> Bool {
        let normalizedParent = parentPath.hasSuffix("/") ? parentPath : "\(parentPath)/"
        guard path.hasPrefix(normalizedParent) else { return false }
        let remainder = path.dropFirst(normalizedParent.count)
        return !remainder.isEmpty && !remainder.contains("/")
    }

    private func shouldInclude(url: URL, options: FileManager.DirectoryEnumerationOptions) -> Bool {
        if options.contains(.skipsHiddenFiles) {
            return !url.lastPathComponent.hasPrefix(".")
        }
        return true
    }
}
