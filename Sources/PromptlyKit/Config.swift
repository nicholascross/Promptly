import Foundation

public struct Config: Decodable {
    /// Model identifier to use for completions.
    public let model: String?
    /// Organization ID for OpenAI-compatible APIs.
    public let organizationId: String?
    /// Resolved API endpoint URL.
    public let chatCompletionsURL: URL
    /// Resolved API token.
    public let token: String

    enum CodingKeys: String, CodingKey {
        case organizationId, model, provider, providers
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
        chatCompletionsURL = try spec.resolveChatCompletionsURL(providerKey: providerKey)
        token = try spec.resolveToken(providerKey: providerKey)
    }

    /// Load configuration from the given file URL.
    public static func loadConfig(url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }
}
