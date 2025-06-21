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

### Homebrew

```bash
brew tap nicholascross/promptly
brew install promptly
```

### Manual

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
- See [Configuration](Docs/configuration.md)

- **tools.json**: Optional JSON file (in your project root or in `~/.config/promptly/`) listing whitelisted shell commands and their parameter schemas.

## Usage

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

### Raw Output

If you need to see the raw JSON stream from the API (including function call metadata), add the `--raw-output` flag:

```bash
echo "some input" | promptly --raw-output "Your context about what to do with the input"
```

### Canned prompts

You can now use predefined prompts for frequent tasks by utilizing the `--canned` (or `-p`) option. This feature simplifies repeated interactions and helps maintain consistency in complex command sequences.

Create canned prompts as text files in the `~/.config/promptly/canned/` directory. 

You can invoke a canned prompt for `example.txt` as follows:

```bash
echo "something" | promptly --canned "example"
```

### Role based messages

You can use the `--message` option to send a predefined series of messages to the chat interface. Note that when using `--message`, standard input and context arguments are ignored.

```bash
promptly --message "system:Respond as a pirate." --message "assistant:Ahoy" --message "user:Can you tell me a story?"
```

In this example:
- The `system` message sets the context of the conversation.
- The `assistant` message is meant to guide the interaction.
- The `user` message is the inquiry from the user.

## License

Promptly is released under the MIT License. See the LICENSE file for more details.

## Acknowledgements

This project has utilized generative AI tools in various aspects of its development, including coding assistance, testing, and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.
