import Foundation
import PromptlyKit
import PromptlyKitUtils

struct SubAgentConfigurationLoader {
    private let fileManager: FileManagerProtocol
    private let credentialSource: CredentialSource

    init(
        fileManager: FileManagerProtocol,
        credentialSource: CredentialSource
    ) {
        self.fileManager = fileManager
        self.credentialSource = credentialSource
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
        let data = try fileManager.readData(at: agentConfigurationURL)
        return try loadAgentConfiguration(
            configFileURL: configFileURL,
            agentConfigurationData: data,
            sourceURL: agentConfigurationURL
        )
    }

    func loadAgentConfiguration(
        configFileURL: URL,
        agentConfigurationData: Data,
        sourceURL: URL
    ) throws -> SubAgentConfiguration {
        let baseDocument = try loadJSONValue(from: configFileURL)
        let agentDocument = try loadJSONValue(from: agentConfigurationData, sourceURL: sourceURL)
        let sanitizedAgentDocument = sanitizeOverrides(agentDocument)
        let merged = merge(base: baseDocument, override: sanitizedAgentDocument)

        let configuration = try decodeMerged(
            merged,
            as: Config.self,
            baseURL: configFileURL,
            agentURL: sourceURL
        )

        let definition = try decodeAgentDefinition(
            from: merged,
            baseURL: configFileURL,
            agentURL: sourceURL
        )

        return SubAgentConfiguration(
            configuration: configuration,
            definition: definition,
            sourceURL: sourceURL
        )
    }

    private func loadJSONValue(from url: URL) throws -> JSONValue {
        do {
            let data = try fileManager.readData(at: url)
            return try loadJSONValue(from: data, sourceURL: url)
        } catch let error as SubAgentConfigurationLoaderError {
            throw error
        } catch {
            throw SubAgentConfigurationLoaderError.invalidConfiguration(url, error)
        }
    }

    private func loadJSONValue(from data: Data, sourceURL: URL) throws -> JSONValue {
        do {
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            guard case .object = value else {
                throw SubAgentConfigurationLoaderError.invalidRootValue(sourceURL)
            }
            return value
        } catch let error as SubAgentConfigurationLoaderError {
            throw error
        } catch {
            throw SubAgentConfigurationLoaderError.invalidConfiguration(sourceURL, error)
        }
    }

    private func decodeMerged<T: Decodable>(
        _ value: JSONValue,
        as _: T.Type,
        baseURL: URL,
        agentURL: URL
    ) throws -> T {
        do {
            return try decode(value, as: T.self)
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

    private func decode<T: Decodable>(
        _ value: JSONValue,
        as _: T.Type
    ) throws -> T {
        let data = try JSONEncoder().encode(value)
        let decoder = JSONDecoder()
        decoder.userInfo[.promptlyCredentialSource] = credentialSource
        return try decoder.decode(T.self, from: data)
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

    private func sanitizeOverrides(_ value: JSONValue) -> JSONValue {
        switch value {
        case let .object(object):
            return .object(sanitizeObject(object, originalWasEmpty: object.isEmpty))
        case let .array(array):
            let sanitized = array.compactMap { sanitizeValue($0) }
            return .array(sanitized)
        default:
            return value
        }
    }

    private func sanitizeObject(
        _ object: [String: JSONValue],
        originalWasEmpty: Bool
    ) -> [String: JSONValue] {
        guard !originalWasEmpty else {
            return object
        }

        var sanitized: [String: JSONValue] = [:]
        sanitized.reserveCapacity(object.count)

        for (key, value) in object {
            guard let sanitizedValue = sanitizeValue(value) else {
                continue
            }
            sanitized[key] = sanitizedValue
        }

        return sanitized
    }

    private func sanitizeValue(_ value: JSONValue) -> JSONValue? {
        switch value {
        case let .string(string):
            let trimmed = string.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : value
        case .null:
            return nil
        case let .object(object):
            let sanitizedObject = sanitizeObject(object, originalWasEmpty: object.isEmpty)
            if !object.isEmpty, sanitizedObject.isEmpty {
                return nil
            }
            return .object(sanitizedObject)
        case let .array(array):
            let sanitized = array.compactMap { sanitizeValue($0) }
            return .array(sanitized)
        default:
            return value
        }
    }
}
