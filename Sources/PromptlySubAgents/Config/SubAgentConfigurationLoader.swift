import Foundation
import PromptlyKit
import PromptlyKitUtils

struct SubAgentConfigurationLoader {
    private let fileManager: FileManagerProtocol

    init(fileManager: FileManagerProtocol) {
        self.fileManager = fileManager
    }

    func agentsDirectoryURL(configFileURL: URL) -> URL {
        configFileURL.standardizedFileURL
            .deletingLastPathComponent()
            .appendingPathComponent("agents", isDirectory: true)
    }

    func agentConfigurationURL(configFileURL: URL, agentName: String) -> URL {
        agentsDirectoryURL(configFileURL: configFileURL)
            .appendingPathComponent("\(agentName).json")
    }

    func discoverAgentConfigurationURLs(configFileURL: URL) throws -> [URL] {
        let directoryURL = agentsDirectoryURL(configFileURL: configFileURL)
        guard fileManager.directoryExists(atPath: directoryURL.path) else {
            return []
        }

        let urls = try fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )

        return urls
            .filter { $0.pathExtension.lowercased() == "json" }
            .sorted {
                $0.lastPathComponent.localizedStandardCompare($1.lastPathComponent) == .orderedAscending
            }
    }

    func loadAgentConfiguration(
        configFileURL: URL,
        agentConfigurationURL: URL
    ) throws -> SubAgentConfiguration {
        let baseDocument = try loadJSONValue(from: configFileURL)
        let agentDocument = try loadJSONValue(from: agentConfigurationURL)
        let merged = merge(base: baseDocument, override: agentDocument)

        let configuration = try decodeMerged(
            merged,
            as: Config.self,
            baseURL: configFileURL,
            agentURL: agentConfigurationURL
        )

        let definition = try decodeAgentDefinition(
            from: merged,
            baseURL: configFileURL,
            agentURL: agentConfigurationURL
        )

        return SubAgentConfiguration(
            configuration: configuration,
            definition: definition,
            sourceURL: agentConfigurationURL
        )
    }

    private func loadJSONValue(from url: URL) throws -> JSONValue {
        do {
            let data = try fileManager.readData(at: url)
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            guard case .object = value else {
                throw SubAgentConfigurationLoaderError.invalidRootValue(url)
            }
            return value
        } catch let error as SubAgentConfigurationLoaderError {
            throw error
        } catch {
            throw SubAgentConfigurationLoaderError.invalidConfiguration(url, error)
        }
    }

    private func decodeMerged<T: Decodable>(
        _ value: JSONValue,
        as _: T.Type,
        baseURL: URL,
        agentURL: URL
    ) throws -> T {
        do {
            return try value.decoded(T.self)
        } catch {
            throw SubAgentConfigurationLoaderError.invalidMergedConfiguration(
                baseURL: baseURL,
                agentURL: agentURL,
                error
            )
        }
    }

    private func decodeAgentDefinition(
        from merged: JSONValue,
        baseURL: URL,
        agentURL: URL
    ) throws -> SubAgentDefinition {
        guard case let .object(root) = merged else {
            throw SubAgentConfigurationLoaderError.invalidRootValue(agentURL)
        }
        guard let agentValue = root["agent"] else {
            throw SubAgentConfigurationLoaderError.missingAgentDefinition(agentURL)
        }
        return try decodeMerged(
            agentValue,
            as: SubAgentDefinition.self,
            baseURL: baseURL,
            agentURL: agentURL
        )
    }

    private func merge(base: JSONValue, override: JSONValue) -> JSONValue {
        switch (base, override) {
        case let (.object(baseObject), .object(overrideObject)):
            if overrideObject.isEmpty {
                return .object([:])
            }
            var merged = baseObject
            for (key, overrideValue) in overrideObject {
                if let baseValue = baseObject[key] {
                    merged[key] = merge(base: baseValue, override: overrideValue)
                } else {
                    merged[key] = overrideValue
                }
            }
            return .object(merged)
        case let (.array, .array(overrideArray)):
            return .array(overrideArray)
        default:
            return override
        }
    }
}
