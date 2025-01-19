import Foundation
import OpenAI

public struct Prompter {

    public init() {}

    /// Prompts the user for a token and stores it in the Keychain.
    public func setupTokenAction() async throws {
        print("Enter your OpenAI API token: ", terminator: "")
        guard let token = readLine(strippingNewline: true), !token.isEmpty else {
            print("Token cannot be empty.")
            return
        }

        do {
            try Keychain().setGenericPassword(account: "openai_token", service: "LLMAssistantService", password: token)
            print("Token stored in Keychain successfully!")
        } catch {
            print("Failed to store token: \(error.localizedDescription)")
        }
    }

    /// Handles reading user input from stdin, loading configuration, retrieving the token,
    /// and sending a query to OpenAI, then prints the result.
    public func runChat(contextArgument: String) async throws {
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
            model: .gpt4_turbo,
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
}
