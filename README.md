# Promptly Project

Promptly is a command-line tool that enables you to interact with OpenAI's API securely by storing your API token in your system's Keychain.

This tool is built using Swift and leverages several dependencies including the [ArgumentParser](https://github.com/apple/swift-argument-parser) for parsing command-line arguments, and [MacPaw/OpenAI](https://github.com/MacPaw/OpenAI.git) for handling API interactions.

## Features

- **Secure API Token Storage**: Store your OpenAI API token securely in the system's Keychain.
- **Command-line Interaction**: Pass a context string directly through the command line to interact with OpenAI's API.

## Requirements

- macOS 10.15 or later
- Swift 6.0 or later
- Xcode or Swift Package Manager

## Installation

To install Promptly, follow these steps:

1. Clone the repository:
   ```bash
   git clone https://github.com/nicholascross/Promptly.git
   cd Promptly
   ```

2. Build using Swift Package Manager:
   ```bash
   swift build -c release
   ```

3. (Optional) Copy the executable to your PATH:
   ```bash
   cp .build/release/Promptly /usr/local/bin/promptly
   ```

## Usage

### Setting Up Your API Token

Before using the tool to make API requests, you need to store your OpenAI API token. Run the following command and follow the prompts:

```bash
promptly --setup-token
```

### Making API Requests

Once your API token is set up, you can make requests by passing a context string as an argument:

```bash
echo "some output to send the llm" | promptly "Your context about what to do with the input"
```

### Help

For more information on available commands and their usage, use the help option:

```bash
promptly --help
```

## Development

To contribute to Promptly, you can follow these steps:

1. Fork the repository and clone your fork.
2. Create a new branch for your feature or fix.
3. Make changes and write tests as necessary.
4. Push your changes and create a pull request against the main Promptly repository.

## Security

Promptly uses the system's Keychain to securely store the OpenAI API token. Always ensure your system is secure and follow best practices for security.

## License

Promptly is released under the MIT License. See the LICENSE file for more details.

## Acknowledgements

This project has utilized generative AI tools in various aspects of its development, including coding assistance, testing and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.

This README was largely generated with promptly. `cat Sources/Promptly/Promptly.swift | ./.build/release/promptly "Create a readme for this project"`
