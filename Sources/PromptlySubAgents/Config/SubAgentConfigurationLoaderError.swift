import Foundation

enum SubAgentConfigurationLoaderError: Error, LocalizedError {
    case invalidConfiguration(URL, Error)
    case invalidMergedConfiguration(baseURL: URL, agentURL: URL, Error)
    case invalidRootValue(URL)
    case missingAgentDefinition(URL)

    var errorDescription: String? {
        switch self {
        case let .invalidConfiguration(url, error):
            return "Invalid configuration at \(url.path): \(error.localizedDescription)"
        case let .invalidMergedConfiguration(baseURL, agentURL, error):
            return
                "Invalid merged configuration from \(baseURL.path) and \(agentURL.path): \(error.localizedDescription)"
        case let .invalidRootValue(url):
            return "Configuration at \(url.path) must be a JSON object."
        case let .missingAgentDefinition(url):
            return "Missing agent definition in \(url.path)."
        }
    }
}
