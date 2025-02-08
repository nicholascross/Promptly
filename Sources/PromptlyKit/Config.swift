import Foundation

public struct Config: Codable {
    public let rawOutput: Bool

    public let host: String
    public let port: Int
    public let scheme: String
    public let path: String

    public let model: String?
    public let tokenName: String?
    public let organizationId: String?

    public init(
        organizationId: String? = nil,
        host: String = "api.openai.com",
        port: Int = 443,
        scheme: String = "https",
        path: String = "v1/chat/completions",
        model: String? = nil,
        tokenName: String? = nil,
        rawOutput: Bool = false
    ) {
        self.organizationId = organizationId
        self.host = host
        self.port = port
        self.scheme = scheme
        self.path = path
        self.model = model
        self.tokenName = tokenName
        self.rawOutput = rawOutput
    }
    
    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        organizationId = try container.decodeIfPresent(String.self, forKey: .organizationId)
        host = try container.decodeIfPresent(String.self, forKey: .host) ?? "api.openai.com"
        port = try container.decodeIfPresent(Int.self, forKey: .port) ?? 443
        scheme = try container.decodeIfPresent(String.self, forKey: .scheme) ?? "https"
        path = try container.decodeIfPresent(String.self, forKey: .path) ?? "v1/chat/completions"
        model = try container.decodeIfPresent(String.self, forKey: .model)
        tokenName = try container.decodeIfPresent(String.self, forKey: .tokenName)
        rawOutput = try container.decodeIfPresent(Bool.self, forKey: .rawOutput) ?? false
    }

    public static func loadConfig(url: URL) throws -> Config {
        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode(Config.self, from: data)
    }
}
