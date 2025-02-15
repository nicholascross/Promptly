import Foundation

public struct Prompter {

    private let url: URL
    private let model: String?
    private let token: String?
    private let organizationId: String?
    private let rawOutput: Bool

    public init(config: Config, rawOutput: Bool) throws {
        let token = try config.tokenName.map {
            try Keychain().genericPassword(
                account: $0,
                service: "Promptly"
            )
        } ?? nil

        let urlString = "\(config.scheme)://\(config.host):\(config.port)/\(config.path)"
        guard let url = URL(string: urlString) else {
            throw PrompterError.invalidConfiguration
        }

        self.url = url
        self.token = token
        self.model = config.model
        self.organizationId = config.organizationId
        self.rawOutput = rawOutput
    }

    public func runChatStream(contextArgument: String) async throws {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let userInput = String(data: inputData, encoding: .utf8) ?? ""

        let request = try makeRequest(url: url, userInput: userInput, contextArgument: contextArgument)

        let (resultStream, response) = try await URLSession.shared.bytes(for: request)
        
        try await handleResult(resultStream, response)
    }

    private func makeRequest(url: URL, userInput: String, contextArgument: String) throws -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("*/*", forHTTPHeaderField: "Accept")

        if let token {
            request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        if let organizationId {
            request.addValue(organizationId, forHTTPHeaderField: "OpenAI-Organization")
        }

        var body: [String: Any] = [
            "stream": true,
            "messages": [
                ["role": "system", "content": contextArgument],
                ["role": "user", "content": userInput]
            ]
            //TODO: might need session_id and or chat_id and or id
        ]

        if let model = model {
            body["model"] = model
        }

        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])
        return request
    }

    private func handleResult(_ resultStream: URLSession.AsyncBytes, _ response: URLResponse) async throws {
        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            print("Streaming request failed with response: \(response)")
            return
        }

        for try await line in resultStream.lines {
            if rawOutput {
                print(line)
                fflush(stdout)
                continue
            }

            // The "line" is each \n-delimited string from the stream

            // If the server is sending SSE, lines might look like:
            // data: { "id":..., "object":"chat.completion.chunk", ... }
            // or eventually: data: [DONE]

            guard !line.isEmpty else { continue }

            if line.starts(with: "data: ") {
                let jsonString = line.dropFirst("data: ".count)

                // Check for [DONE] sentinel
                if jsonString.trimmingCharacters(in: .whitespaces) == "[DONE]" {
                    // End of stream
                    break
                }

                // Attempt to decode the chunk as JSON
                do {
                    let dataChunk = Data(jsonString.utf8)
                    let event = try JSONDecoder().decode(ChatResponse.self, from: dataChunk)

                    // Print partial or final tokens
                    if let delta = event.choices.first?.delta?.content {
                        print(delta, terminator: "")
                        fflush(stdout) // ensure partial output is shown promptly
                    }
                } catch {
                    // Possibly a ping line, or partial data
                    // You might just print or ignore
                    // print("Failed to decode line: \(line)")
                }
            } else {
                // Some servers might not use `data:` prefix
                // You can parse raw JSON or partial tokens here
                // For demonstration, printing raw
                print(line)
            }
        }

        print("")
    }
}
