import Foundation

public struct Config: Decodable {
    /// Model identifier to use for completions.
    public let model: String?
    /// Optional mapping of alias names to model identifiers.
    public let modelAliases: [String: String]
    /// Organization ID for OpenAI-compatible APIs.
    public let organizationId: String?
    /// Resolved API endpoint URL.
    public let chatCompletionsURL: URL
    /// Resolved API token.
    public let token: String

    enum CodingKeys: String, CodingKey {
        case organizationId, model, modelAliases, provider, providers
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        let providerKey = try container.decode(String.self, forKey: .provider)
        let specs = try container.decode([String: ProviderSpec].self, forKey: .providers)

        guard let spec = specs[providerKey] else {
            throw DecodingError.dataCorruptedError(
                forKey: .provider,
                in: container,
                debugDescription: "Invalid provider key '\(providerKey)'"
            )
        }

        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        model = try container.decodeIfPresent(String.self, forKey: .model)
        modelAliases = try container.decodeIfPresent([String: String].self, forKey: .modelAliases) ?? [:]
        chatCompletionsURL = try spec.resolveChatCompletionsURL(providerKey: providerKey)
        token = try spec.resolveToken(providerKey: providerKey)
    }

    /// Load configuration from the given file URL.
    public static func loadConfig(url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }

    /// Return the effective model identifier, applying any aliases for override or default.
    /// - Parameter override: Optional model override (e.g. from CLI).
    public func resolveModel(override: String? = nil) -> String? {
        guard let raw = override ?? model else { return nil }
        return modelAliases[raw] ?? raw
    }
}
