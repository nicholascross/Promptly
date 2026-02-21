import Foundation

public struct BundledAgentDefaults {
    private let resourceLoader: BundledResourceLoader

    public init(resourceLoader: BundledResourceLoader = BundledResourceLoader()) {
        self.resourceLoader = resourceLoader
    }

    public func agentNames() -> [String] {
        resourceLoader.listResources(
            subdirectory: BundledDefaultAssetPaths.agents,
            fileExtension: "json"
        )
    }

    public func agentData(name: String) -> Data? {
        resourceLoader.loadDataResource(
            subdirectory: BundledDefaultAssetPaths.agents,
            name: name,
            fileExtension: "json"
        )
    }

    public func agentURL(name: String) -> URL? {
        resourceLoader.resourceURL(
            subdirectory: BundledDefaultAssetPaths.agents,
            name: name,
            fileExtension: "json"
        )
    }
}
