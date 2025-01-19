import Foundation
import OpenAI

public struct Prompter {

    public init() {}

    /// Prompts the user for a token and stores it in the Keychain.
    public func setupTokenAction() async throws {
        print("Are you setting up (1) OpenAI or (2) Open WebUI token? [1/2] ", terminator: "")
            guard let choice = readLine(), !choice.isEmpty else {
                print("Invalid choice.")
                    return
            }

        print("Enter your API token: ", terminator: "")
            guard let token = readLine(strippingNewline: true), !token.isEmpty else {
                print("Token cannot be empty.")
                    return
            }

        let accountName = (choice == "2") ? "openwebui_token" : "openai_token"
            do {
                try Keychain().setGenericPassword(account: accountName,
                        service: "Promptly",
                        password: token)
                    print("Token stored in Keychain under \(accountName).")
            } catch {
                print("Failed to store token: \(error.localizedDescription)")
            }
    }

    /// Handles reading user input from stdin, loading configuration, retrieving the token,
    /// and sending a query to OpenAI, then prints the result.
    public func runChatOpenAI(contextArgument: String) async throws {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let userInput = String(data: inputData, encoding: .utf8) ?? ""

        let config = try Config.loadConfig()

        guard let token = try Keychain().genericPassword(
            account: "openai_token",
            service: "Promptly"
        ) else {
            throw PrompterError.tokenNotSpecified
        }

        let openAIConfig = OpenAI.Configuration(
            token: token,
            organizationIdentifier: config.organizationId,
            host: config.host ?? "api.openai.com",
            port: config.port ?? 443,
            timeoutInterval: 60.0
        )
        let openAI = OpenAI(configuration: openAIConfig)

        let query = ChatQuery(
            messages: [
                .system(.init(content: contextArgument)),
                .user(.init(content: .string(userInput)))
            ],
            model: config.model ?? .gpt4_turbo,
            maxTokens: 500,
            temperature: 0.7
        )

        for try await result in openAI.chatsStream(query: query) {
            if let firstChoice = result.choices.first,
               let content = firstChoice.delta.content {
                    print(content, terminator: "")
            }
        }
    }

    public func runChatOpenWebUIStream(contextArgument: String) async throws {
        let inputData = FileHandle.standardInput.readDataToEndOfFile()
        let userInput = String(data: inputData, encoding: .utf8) ?? ""

        let config = try Config.loadConfig()

        guard let token = try Keychain().genericPassword(
            account: "openwebui_token",
            service: "Promptly"
        ) else {
            throw PrompterError.tokenNotSpecified
        }

        guard
            let host = config.openWebUIHost,
            let port = config.openWebUIPort,
            let model = config.openWebUIModel
        else {
            throw PrompterError.openWebUIConfigNotSpecified
        }

        let urlString = "https://\(host):\(port)/api/chat/completions"
        guard let url = URL(string: urlString) else {
            throw PrompterError.openWebUIConfigNotSpecified
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.addValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.addValue("application/json", forHTTPHeaderField: "Content-Type")
        request.addValue("*/*", forHTTPHeaderField: "Accept")

        let body: [String: Any] = [
            "model": model,
            "stream": true,
            "messages": [
                ["role": "system", "content": contextArgument],
                ["role": "user", "content": userInput]
            ]
            //TODO: might need session_id and or chat_id and or id
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body, options: [])

        let (resultStream, response) = try await URLSession.shared.bytes(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              200...299 ~= httpResponse.statusCode else {
            print("Open WebUI streaming request failed with response: \(response)")
            return
        }

        for try await line in resultStream.lines {
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
                    let event = try JSONDecoder().decode(OpenAIStreamChunk.self, from: dataChunk)

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

struct OpenAIStreamChunk: Decodable {
    let id: String?
    let object: String?
    let created: Int?
    let model: String?
    let choices: [Choice]

    struct Choice: Decodable {
        let index: Int?
        let delta: Delta?

        struct Delta: Decodable {
            let role: String?
            let content: String?
        }
    }
}
