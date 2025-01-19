import Foundation

struct Config: Decodable {
    let organizationId: String?
    let host: String?
    let port: Int?

    init() {
        organizationId = nil
        host = nil
        port = nil
    }

    static func loadConfig() throws -> Config {
        let homeDir = FileManager.default.homeDirectoryForCurrentUser
            let configURL = homeDir.appendingPathComponent(".config/pllm/config.json")

            do {
                let data = try Data(contentsOf: configURL)
                return try JSONDecoder().decode(Config.self, from: data)
            } catch {
                return Config()
            }
    }
}
