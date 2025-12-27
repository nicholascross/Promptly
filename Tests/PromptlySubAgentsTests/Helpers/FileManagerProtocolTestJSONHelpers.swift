import Foundation
import PromptlyKit
import PromptlyKitUtils

extension FileManagerProtocol {
    func writeJSONValue(_ value: JSONValue, to url: URL) throws {
        let data = try JSONEncoder().encode(value)
        try writeData(data, to: url)
    }

    func writeShellCommandConfig(_ config: ShellCommandConfig, to url: URL) throws {
        let data = try JSONEncoder().encode(config)
        try writeData(data, to: url)
    }

    func loadJSONLines(from url: URL) throws -> [JSONValue] {
        let data = try readData(at: url)
        let contents = String(decoding: data, as: UTF8.self)
        let lines = contents.split(separator: "\n", omittingEmptySubsequences: true)
        var entries: [JSONValue] = []
        entries.reserveCapacity(lines.count)
        for line in lines {
            let data = Data(line.utf8)
            let value = try JSONDecoder().decode(JSONValue.self, from: data)
            entries.append(value)
        }
        return entries
    }
}
