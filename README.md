# Promptly Project

Promptly is a versatile command-line tool designed to interact with OpenAI's API for completions, as well as compatible APIs such as Ollama, OpenWebUI, and llama-cpp.

## Examples

```bash
# Piping content to an LLM and piping the output back to another command
git diff --staged | promptly "Write a commit message that explains the changes in this diff" | pbcopy
```

```bash
# Update project readme for staged changes
(cat README.md; echo; git diff --staged) | promptly "Update the readme for the following changes. When making any modifications to examples, ensure they are relevant to real-world use cases." > README.md
```

For more detailed examples and usage, check out the [Cookbook](Docs/cookbook.md).

## Features

- **Secure API Token Storage**: Safely store your OpenAI (and compatible APIs) in the system's Keychain.
- **Flexible API Interaction**: Choose to interact with OpenAI's API or compatible APIs such as OpenWebUI based on your configuration.
- **Command-Line Interface**: Directly pass context strings through the command line to interact with the chosen API.

## Requirements

- macOS 14 or later
- Swift 6.0 or later
- Xcode or Swift Package Manager

## Installation

To install Promptly, execute the following steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/nicholascross/Promptly.git
   cd Promptly
   ```

2. Build using Swift Package Manager:
   ```bash
   swift build -c release
   ```

3. Copy the executable to your PATH:
   ```bash
   cp .build/release/Promptly ~/bin/promptly
   ```

## Configuration

1. Create the Config File
   ```bash
   mkdir -p ~/.config/promptly
   touch ~/.config/promptly/config.json
   ```

2. Example Configuration
   ```json
   {
     "scheme": "http",
     "host": "webui.example.com",
     "port": 5678,
     "model": "gpt-3.5-turbo"
   }
   ```

3. Parameter Overview
   - model: Model identifier.
   - host (default: api.openai.com): API host address.
   - port (default: 443): API port number.
   - scheme (default: https): API scheme, 'http' or 'https'.
   - path (default: v1/chat/completions): completions API path.
   - organizationId (optional): Your organization ID for OpenAI.
   - rawOutput (default: false): When true, the raw response stream is output.

### Using llama.cpp

Launch the llama server:
```bash
llama-server -hf bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF
```

Config:
```json
{
  "host": "localhost",
  "port": 8080,
  "scheme": "http"
}
```

### Using Ollama

Config:
```json
{
  "model": "qwen2.5-coder:7b",
  "scheme": "http",
  "port": 11434,
  "host": "localhost",
  "tokenName": "ollama"
}
```

### Using OpenAI

Config:
```json
{
  "organizationId": "org-123",
  "model": "gpt-4o-mini",
  "tokenName": "openai"
}
```

### Using OpenWebUI

Config:
```json
{
  "path": "api/chat/completions",
  "tokenName": "openwebui"
}
```

### Setting Up Your API Token

Before utilizing the tool to make API requests, you must store your API token. Execute the following command and adhere to the prompts:
```bash
promptly --setup-token
```

### Making API Requests

After setting up your API token, you can initiate requests by passing a context string as an argument:
```bash
echo "some output to send the LLM" | promptly "Your context about what to do with the input"
```

### Role based messages

You can use the `--message` option to send a predefined series of messages to the chat interface. Note that when using `--message`, standard input and context arguments are ignored.

```bash
promptly --message "system:Respond as a pirate." --message "assistant:Ahoy" --message "user:Can you tell me a story?"
```

In this example:
- The `system` message sets the context of the conversation.
- The `assistant` message is meant to guide the interaction.
- The `user` message is the inquiry from the user about the project.

### Help

For additional information on available commands and their usage, refer to the help option:
```bash
promptly --help
```

## Development

To contribute to Promptly, you can follow these steps:

1. Fork the repository and clone your fork.
2. Create a new branch for your feature or fix.
3. Make modifications and write tests as necessary.
4. Push your changes and create a pull request against the main Promptly repository.

## Security

Promptly employs the system's Keychain to securely store the OpenAI API token. Always ensure your system is secure and follow best practices for security.

## License

Promptly is released under the MIT License. See the LICENSE file for more details.

## Acknowledgements

This project has utilized generative AI tools in various aspects of its development, including coding assistance, testing, and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.
