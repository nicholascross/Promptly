# Promptly Project

Promptly is a versatile command-line tool designed to interact with OpenAI's API and OpenWebUI, ensuring secure API token management by storing your token in your system's Keychain. This tool is crafted using Swift and incorporates dependencies such as [ArgumentParser](https://github.com/apple/swift-argument-parser) for parsing command-line arguments, and [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI.git) for API interactions.

## Features

- **Secure API Token Storage**: Safely store your OpenAI (and compatible APIs) or OpenWebUI API token in the system's Keychain.
- **Flexible API Interaction**: Choose to interact with either OpenAI's API or the OpenWebUI based on your configuration.
- **Command-line Interface**: Directly pass context strings through the command line to interact with the chosen API.

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

1.	Create the Config File

```bash
mkdir -p ~/.config/promptly
touch ~/.config/promptly/config.json
```

2.	Example Configuration
 
```json
{
  "useOpenWebUI": true,
  "openWebUIHost": "webui.example.com",
  "openWebUIPort": 5678,
  "openWebUIModel": "gpt-3.5-turbo"
}
```
3.	Parameter Overview
 
- organizationId: Your organization ID for OpenAI.
- host (default: api.openai.com): API host address.
- port (default: 443): API port number.
- scheme (default: https): API scheme, 'http' or 'https'.
- usesToken (default: true): Allow an empty token if false.
- model (default: gpt4_turbo): Model identifier for OpenAI.
- useOpenWebUI (default: false): Enables OpenWebUI if set to true.
- openWebUIHost: Host address for OpenWebUI.
- openWebUIPort: Port number for OpenWebUI.
- openWebUIModel: Model identifier for OpenWebUI.

## Usage

### Using llama.cpp via the OpenAI api

Launch the llama server (example without using an API token):
```bash
llama-server -hf bartowski/DeepSeek-R1-Distill-Qwen-32B-GGUF
```

Config:

```json
{
  "host": "localhost",
  "port": 8080,
  "scheme": "http",
  "usesToken": false
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
echo "some output to send the llm" | promptly "Your context about what to do with the input"
```

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

This project has utilized generative AI tools in various aspects of its development, including coding assistance, testing and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.

This README was largely generated with promptly.

```bash
cat Sources/Promptly/Promptly.swift | ./.build/release/promptly "Create a readme for this project"
```
