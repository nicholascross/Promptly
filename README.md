# Promptly

[![Release Version](https://img.shields.io/github/v/release/nicholascross/Promptly)](https://github.com/nicholascross/Promptly/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Homebrew](https://img.shields.io/badge/homebrew-promptly-informational?logo=homebrew)](https://github.com/nicholascross/homebrew-promptly)

Promptly is a Swift-based command line tool that helps you work with large language models from the terminal. It supports OpenAI and compatible providers including local hosts (Ollama, llama.cpp). Promptly includes secure token storage, canned prompts, sub agents, and safe shell command integrations for automation.

## Project status

This is a source available project. API and feature stability are not a goal, and breaking changes are expected as the project evolves.

## Highlights

- Multi-provider support across hosted services and local hosts.
- Secure token storage in the system Keychain.
- One-off commands with piped input and an interactive session mode.
- Canned prompts and configurable shell tools for repeatable workflows.
- Sub agents for specialized workflows and tool isolation.

For more details on configuration, shell tools, canned prompts, and sub agents, see the documentation links in the Documentation section.

## Quick start

```bash
brew tap nicholascross/promptly
brew install promptly

promptly token setup

echo "Summarize this change log." | promptly "Write a short release note summary."
```

## Examples

```bash
# Generate a concise commit message from the staged diff and copy to clipboard
git diff --staged | promptly --message "user:Write a concise commit message for the staged changes." | pbcopy
```

```bash
# Use a canned prompt named "refactor" to improve Main.swift
cat Sources/App/Main.swift | promptly --canned refactor
```

```bash
# Display the project directory structure using the ShowFileTree tool
promptly --include-tools ShowFileTree --message "user:Display the project directory structure."
```

## Requirements

- macOS 14 or later
- Swift 6.0 or later
- Xcode or Swift Package Manager

## Installation

### Homebrew (recommended)

```bash
brew tap nicholascross/promptly
brew install promptly
```

### Manual build

1. Clone the repository:
   ```bash
   git clone https://github.com/nicholascross/Promptly.git
   cd Promptly
   ```

2. Build using Swift Package Manager:
   ```bash
   swift build -c release
   ```

3. Copy the executable to your path:
   ```bash
   cp .build/release/Promptly ~/bin/promptly
   ```

Default agents and canned prompts ship in the PromptlyAssets resource bundle. When building manually, copy the resource bundle next to the executable or set `PROMPTLY_RESOURCE_BUNDLE` to the bundle path. Homebrew installs include the resource bundle alongside the executable.

## Usage

### Store your application programming interface token

```bash
promptly token setup
```

For provider, model, and token configuration, see [Configuration](Docs/configuration.md).

### Send input by pipe

```bash
echo "some output to send" | promptly "Your context about what to do with the input"
```

### Interactive session

```bash
promptly --interactive --message "system:You are an bumbling assistant."
```

Press Control-D or Control-C to exit the interactive session.

### Terminal user interface

```bash
promptly ui
```

Terminal user interface mode requires an interactive terminal.

### Canned prompts

Promptly ships bundled canned prompts and loads them on demand. To override or add new prompts, create text files in `~/.config/promptly/canned/`.
See [Canned prompts](Docs/canned.md) for bundled prompt content and examples.

```bash
promptly canned list

echo "something" | promptly --canned example
```

### Messages with roles

Use the `--message` option to send multiple role-prefixed messages (system, assistant, user).

```bash
promptly --message "system:Respond as a pirate." --message "assistant:Ahoy" --message "user:Can you tell me a story?"
```

### Shell tools

Shell tools are allow listed and can be limited with include or exclude filters. Provide natural language instructions in your message body.
See [Shell tools](Docs/shell-tools.md) for configuration details and [Shell tools reference](Docs/tools.json) for the default tool definitions.

```bash
promptly --include-tools ShowFileTree --message "user:Display the project directory structure."
```

### Sub agents

Manage sub agents with the `promptly agent` commands. For a full list of options, run `promptly agent --help`.
See [Sub agents](Docs/sub-agents.md) for configuration details and [Self tests](Docs/self-test.md) for the sub agent self test workflow.

```bash
promptly agent list
```

## Documentation

- Configuration guide: [Configuration](Docs/configuration.md)
- Sub agents: [Sub agents](Docs/sub-agents.md)
- Shell tools: [Shell tools](Docs/shell-tools.md)
- Self tests: [Self tests](Docs/self-test.md)
- Bundled canned prompts: [Canned prompts](Docs/canned.md)

## License

Promptly is released under the MIT License. See the LICENSE file for more details.

## Acknowledgements

This project has utilized generative artificial intelligence tools in various aspects of its development, including coding assistance, testing, and documentation enhancement. The use of these tools has contributed to the efficiency and effectiveness of the development process.
