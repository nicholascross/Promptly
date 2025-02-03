import Foundation

public struct Config: Decodable {
    public let organizationId: String?
    public let host: String?
    public let port: Int?
    public let scheme: String?
    public let model: String?
    public let usesToken: Bool?

    public let useOpenWebUI: Bool?
    public let openWebUIHost: String?
    public let openWebUIPort: Int?
    public let openWebUIModel: String?

    public init() {
        organizationId = nil
        host = nil
        port = nil
        scheme = nil
        model = nil
        usesToken = nil

        useOpenWebUI = false
        openWebUIHost = nil
        openWebUIPort = nil
        openWebUIModel = nil
    }

    public static func loadConfig(file: String) throws -> Config {
        let configURL = URL(filePath: NSString(string: file).expandingTildeInPath)

        do {
            let data = try Data(contentsOf: configURL)
            return try JSONDecoder().decode(Config.self, from: data)
        } catch {
            // If missing or invalid config, just return defaults
            return Config()
        }
    }
}
