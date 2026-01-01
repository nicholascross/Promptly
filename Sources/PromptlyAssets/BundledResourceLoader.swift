import Foundation
import PromptlyKitUtils

public struct BundledResourceLoader {
    private let fileManager: FileManagerProtocol
    private let environment: [String: String]
    private let executableURLProvider: () -> URL?

    public init(
        fileManager: FileManagerProtocol = FileManager.default,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        executableURLProvider: @escaping () -> URL? = { Bundle.main.executableURL }
    ) {
        self.fileManager = fileManager
        self.environment = environment
        self.executableURLProvider = executableURLProvider
    }

    public func resolveBundle() -> Bundle? {
        if let bundle = findModuleResourceBundle() {
            return bundle
        }
        if let override = environment["PROMPTLY_RESOURCE_BUNDLE"] {
            let trimmed = override.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty, let bundle = bundleAtPath(trimmed) {
                return bundle
            }
        }
        return findBundleAdjacentToExecutable()
    }

    public func resourceURL(
        subdirectory: String,
        name: String,
        fileExtension: String
    ) -> URL? {
        guard let bundle = resolveBundle() else {
            return nil
        }
        return bundle.url(
            forResource: name,
            withExtension: fileExtension,
            subdirectory: subdirectory
        )
    }

    public func loadTextResource(
        subdirectory: String,
        name: String,
        fileExtension: String
    ) -> String? {
        guard let url = resourceURL(
            subdirectory: subdirectory,
            name: name,
            fileExtension: fileExtension
        ) else {
            return nil
        }
        guard let data = try? fileManager.readData(at: url) else {
            return nil
        }
        return String(data: data, encoding: .utf8)
    }

    public func loadDataResource(
        subdirectory: String,
        name: String,
        fileExtension: String
    ) -> Data? {
        guard let url = resourceURL(
            subdirectory: subdirectory,
            name: name,
            fileExtension: fileExtension
        ) else {
            return nil
        }
        return try? fileManager.readData(at: url)
    }

    public func listResources(
        subdirectory: String,
        fileExtension: String
    ) -> [String] {
        guard let bundle = resolveBundle() else {
            return []
        }
        let urls = bundle.urls(
            forResourcesWithExtension: fileExtension,
            subdirectory: subdirectory
        ) ?? []
        let names = urls.map { $0.deletingPathExtension().lastPathComponent }
        let uniqueNames = Set(names)
        return uniqueNames.sorted()
    }

    private func findModuleResourceBundle() -> Bundle? {
        if let bundle = bundleIfContainsDefaultAssets(Bundle.module) {
            return bundle
        }
        if let bundle = bundleIfContainsDefaultAssets(Bundle.main) {
            return bundle
        }
        let moduleBundle = Bundle(for: ModuleBundleFinder.self)
        if let bundle = bundleIfContainsDefaultAssets(moduleBundle) {
            return bundle
        }
        for candidate in moduleBundleCandidates() {
            if let bundle = bundleContainingDefaultAssets(in: candidate) {
                return bundle
            }
        }
        return nil
    }

    private func moduleBundleCandidates() -> [URL] {
        var candidates: [URL] = []
        let mainBundle = Bundle.main
        if let resourceURL = mainBundle.resourceURL {
            candidates.append(resourceURL)
        }
        candidates.append(mainBundle.bundleURL)

        let moduleBundle = Bundle(for: ModuleBundleFinder.self)
        if let resourceURL = moduleBundle.resourceURL {
            candidates.append(resourceURL)
        }
        candidates.append(moduleBundle.bundleURL)
        return candidates
    }

    private func findBundleAdjacentToExecutable() -> Bundle? {
        guard let executableURL = executableURLProvider()?.resolvingSymlinksInPath() else {
            return nil
        }
        let directoryURL = executableURL.deletingLastPathComponent()
        return bundleContainingDefaultAssets(in: directoryURL)
    }

    private func bundleAtPath(_ path: String) -> Bundle? {
        let url = URL(fileURLWithPath: path).standardizedFileURL
        guard hasDefaultAssetsDirectory(at: url) else {
            return nil
        }
        return Bundle(url: url)
    }

    private func bundleContainingDefaultAssets(in directory: URL) -> Bundle? {
        if hasDefaultAssetsDirectory(at: directory) {
            return Bundle(url: directory)
        }
        let candidates = (try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )) ?? []
        for candidate in candidates where candidate.pathExtension == "bundle" {
            if hasDefaultAssetsDirectory(at: candidate) {
                return Bundle(url: candidate)
            }
        }
        return nil
    }

    private func hasDefaultAssetsDirectory(at url: URL) -> Bool {
        let assetsURL = url.appendingPathComponent("DefaultAssets", isDirectory: true)
        return fileManager.directoryExists(atPath: assetsURL.path)
    }

    private func bundleIfContainsDefaultAssets(_ bundle: Bundle) -> Bundle? {
        guard let resourceURL = bundle.resourceURL,
              hasDefaultAssetsDirectory(at: resourceURL) else {
            return nil
        }
        return bundle
    }
}

private final class ModuleBundleFinder {}
