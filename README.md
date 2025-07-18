# Promptly

[![Release Version](https://img.shields.io/github/v/release/nicholascross/Promptly)](https://github.com/nicholascross/Promptly/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Homebrew](https://img.shields.io/badge/homebrew-promptly-informational?logo=homebrew)](https://github.com/nicholascross/homebrew-promptly)

Promptly is a Swift-based CLI tool that streamlines interaction with large language models. It supports OpenAI and OpenAI-compatible providers (Azure OpenAI, OpenRouter, Gemini, Mistral, DeepSeek, xAI, Groq, ArceeAI) as well as local hosts (Ollama, llama.cpp). Promptly features secure API token management, interactive and piped modes, customizable canned prompts, and sandboxed shell command integrations for flexible automation.

## Examples

```bash
# Generate a concise commit message from the staged diff and copy to clipboard
git diff --staged | promptly --message "user:Write a concise commit message for the staged changes" | pbcopy
```

```bash
# Update project README from staged diff using default tools.json configuration
git diff --staged | promptly --message "user:Update the README for the changes in the diff"
```

```bash
# Use a canned prompt named 'refactor' to improve Main.swift
cat Sources/App/Main.swift | promptly --canned refactor
```

```bash
# Display the project's directory structure using the ShowFileTree tool
promptly --include-tools ShowFileTree --message "user:Display the project's directory structure"
```

## Features

- **Multi‑provider support**: Work with OpenAI and OpenAI‑compatible services (Azure OpenAI, OpenRouter, Gemini, Mistral, DeepSeek, xAI, Groq, ArceeAI) as well as local hosts (Ollama, llama.cpp).
- **Secure API token storage**: Safely store your API keys in the system Keychain.
- **Piped and interactive modes**: Send context through stdin in one‑off commands or start a persistent interactive REPL session.
- **Canned prompts**: Create and reuse predefined prompts via text files in `~/.config/promptly/canned`.
- **Sandboxed shell command integrations**: Expose allow‑listed shell tools with path validation to automate common workflows.
- **Flexible configuration**: Customize providers, models, and tool behaviors through JSON config files.

## Quick Reference

| Flag                    | Description                                      |
|-------------------------|--------------------------------------------------|
| `-i`, `--interactive`   | Start REPL mode                                  |
| `-p`, `--canned <name>` | Use a canned prompt from `~/.config/promptly/canned` |
| `--include-tools`       | Whitelist shell tools by substring               |
| `--exclude-tools`       | Blacklist shell tools by substring               |
| `-c`, `--config <path>`  | Override config file path (default `~/.config/promptly/config.json`) |
| `--tools <name>`         | Override shell tools config basename (default `tools`) |
| `--setup-token`          | Store or update the API token in Keychain        |
| `--model <id>`           | Override the default model identifier            |
| `--message <role:msg>`   | Send a prefixed chat message (roles: user, system, assistant; e.g. `user:Hi`) |

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

### Interactive Mode

To start an interactive session where you can send multiple prompts without restarting the command, use the `--interactive` flag. For example:

```bash
# Start an interactive session with an initial system prompt
promptly --interactive --message "user:You are a helpful assistant."

# At each '>' prompt, type your input and press Enter:
> Hello, how are you?
I'm doing well, thank you! How can I assist you today?

> Tell me a joke.
Why did the developer go broke? Because he used up all his cache.

# Press Ctrl-D (EOF) / Ctrl-C to exit interactive mode.
```

### Canned prompts

You can now use predefined prompts for frequent tasks by utilizing the `--canned` (or `-p`) option. This feature simplifies repeated interactions and helps maintain consistency in complex command sequences.

Create canned prompts as text files in the `~/.config/promptly/canned/` directory. 

You can invoke a canned prompt for `example.txt` as follows:

```bash
echo "something" | promptly --canned "example"
```

### Role based messages

You can use the `--message` option to send a predefined series of messages to the chat interface. Note that when using `--message`, standard input and context arguments are ignored. Supported roles are `system`, `assistant`, and `user`.

```bash
promptly --message "system:Respond as a pirate." --message "assistant:Ahoy" --message "user:Can you tell me a story?"
```

In this example:
- The `system` message sets the context of the conversation.
- The `assistant` message is meant to guide the interaction.
- The `user` message is the inquiry from the user.

### Filtering Available Tools

You can restrict which shell-command tools are exposed to the LLM by using the `--include-tools` option. Provide one or more tool name substrings; only matching tools will be loaded.

You can also exclude specific shell-command tools by using the `--exclude-tools` option. Provide one or more tool name substrings; any matching tools will be omitted from the loaded set.

```bash
promptly --include-tools ShowFileTree --message "user:what is this project"
```

```bash
promptly --exclude-tools RemoveMe --message "user:what is this project"
```

## License

Promptly is released under the MIT License. See the LICENSE file for more details.

## Acknowledgements

This project has utilized generative AI tools in various aspects of its development, including coding assistance, testing, and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.
