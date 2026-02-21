# Promptly

[![Release Version](https://img.shields.io/github/v/release/nicholascross/Promptly)](https://github.com/nicholascross/Promptly/releases)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Homebrew](https://img.shields.io/badge/homebrew-promptly-informational?logo=homebrew)](https://github.com/nicholascross/homebrew-promptly)

Promptly is a runtime for building software that an AI can operate.

It provides an execution loop that sends messages to a model, executes model-requested tools, feeds tool outputs back to the model, and returns structured conversation entries. The project ships as a command line interface and as reusable Swift libraries.

## Project status

This is a source-available project under active change. Breaking changes are expected.

## What is Promptly?

Promptly is both:

- A runtime (`PromptlyKit`) for model-driven execution with tools
- An execution environment (`PromptlyKitTooling`, `PromptlySubAgents`, `PromptlyDetachedTask`) for capabilities, delegation, and follow-up handling
- A command line interface first workflow tool (`promptly`) for interactive terminal use, tool management, canned prompts, sub agents, and self tests

The runtime is provider-compatible through OpenAI-style APIs (Responses and Chat Completions), configured by provider URL and credentials.

## How it works

At runtime, Promptly follows this loop:

1. Build a run context from messages (or a resume token for Responses).
2. Send the request through a provider adapter (`PromptTurnEndpoint`).
3. Stream events (`assistantTextDelta`, tool call requested, tool call completed).
4. If the model requested tools, execute matching `ExecutableTool` implementations.
5. Submit tool outputs back to the provider endpoint.
6. Repeat until there are no more tool calls.
7. Return `PromptRunResult` with `conversationEntries` and optional `resumeToken`.

The loop is implemented in `PromptRunExecutor`, behind the public `PromptRunCoordinator` API.

## Core concepts

- `PromptRunCoordinator`: Public entry point to run a prompt session.
- `PromptRunContext`: Either `.messages(...)` or `.resume(resumeToken:requestMessages:)`.
- `PromptRunResult`: Returned entries (`PromptMessage`) plus optional resume token.
- `ExecutableTool`: Capability contract (name, description, JSON schema, async execute).
- `PromptStreamEvent`: Provider-neutral stream of assistant deltas and tool lifecycle events.
- Shell tools: Loaded from `tools.json` definitions and exposed as `ExecutableTool` values.
- Sub agents: Loaded as tools (`SubAgent-<name>`) and executed through detached task sessions.
- Return contract for sub agents: `ReturnToSupervisor` payload with optional `resumeId` and `logPath`.

## Architecture overview

### Library-level modules

- `PromptlyKit`: Core runtime, prompt coordination, provider adapters, stream events, session loop.
- `PromptlyKitTooling`: Shell command tool loading and execution, argument templates, built-in `ApplyPatch`.
- `PromptlySubAgents`: Sub agent configuration loading, tool factory, supervisor recovery logic.
- `PromptlyDetachedTask`: Detached task orchestration, resume strategies, transcript logging.
- `PromptlyConsole`: Console runner and interactive conversation loop.

### Command line interface specific module

- `Promptly` executable target:
  - `prompt` (default): run one-shot or interactive sessions
  - `ui`: terminal user interface mode
  - `tool`: manage tool definitions
  - `agent`: manage and run sub agents
  - `canned`: manage canned prompts
  - `token`: store or update provider token in Keychain
  - `self-test`: run runtime, tool, and sub agent checks

### Runtime boundary

Promptly keeps a clear boundary between reasoning and execution:

- Model reasoning happens through provider endpoints.
- Execution happens only via explicit tool calls.
- Tool outputs are serialized as JavaScript Object Notation and fed back into the loop.

## Example flow

A typical command line interface run with tools enabled:

1. User starts `promptly` with messages and tool filters.
2. Command line interface loads config, tools, and optional sub agent tools.
3. `PromptRunCoordinator` sends the request to the selected API (`responses` or `chat`).
4. Model emits text deltas and may request a tool.
5. Promptly executes the tool and emits completion events.
6. Tool output is returned to the model for continuation.
7. Final assistant output and tool interactions are returned as `conversationEntries`.

For sub agent follow-up cases (`needsMoreInformation` or `needsSupervisorDecision`), Promptly can recover a missing resume identifier by running one recovery cycle before asking the user for additional input.

## Session and transcript behavior

- Main prompt sessions: conversation state is held in memory by the runner.
- Runtime resume token:
  - Responses API: supported (`PromptRunResult.resumeToken`, `PromptRunContext.resume`).
  - Chat Completions API: resume token is not supported; continuation requires full messages.
- Sub agent continuation: uses `resumeId` managed by `DetachedTaskResumeStore` during the running process.
- Sub agent transcripts: detached task runs can log JavaScript Object Notation Lines transcripts under the configuration directory in `agents/logs/<agent-name>/...` when log sink initialization succeeds.

## Tool execution and safety model

Promptly uses explicit tool definitions and filtering:

- Tools are allow-listed from configuration files (`local`, `user`, `bundled`), plus built-in tools.
- Include and exclude filters control which tools are loaded.
- `optIn` tools are disabled by default unless explicitly included.
- `{(path)}` argument template placeholders enforce workspace-relative path checks in shell tools.
- Built-in `ApplyPatch` applies diffs through a sandboxed workspace file system root.

Important: shell commands still execute as local processes. Safety depends on tool definitions, argument templates, and your include and exclude policy.

## Streaming support

Streaming is first-class in the runtime:

- Responses API: server-sent events are parsed incrementally; assistant text deltas are emitted as they arrive.
- Chat Completions API: streamed chunks are processed into content and tool call events.
- Output handling is provider-neutral via `PromptStreamEvent`.

## Command line interface usage

### Install

```bash
brew tap nicholascross/promptly
brew install promptly
```

### Configure credentials

```bash
promptly token setup
```

### One-shot run

```bash
promptly --message "user:Summarize the latest changes in this repository."
```

### Interactive run

```bash
promptly --interactive --message "system:Be concise and technical."
```

### Terminal user interface

```bash
promptly ui
```

### Use a tool via natural language instructions

```bash
promptly --include-tools ShowFileTree --message "user:Show the project directory tree."
```

### Work with sub agents

```bash
promptly agent list
promptly agent view refactor
promptly agent run refactor "Refactor the parser without changing behavior."
```

### Run built-in self tests

```bash
promptly self-test basic
promptly self-test tools
promptly self-test agents
```

## Design principles

- Runtime-first design: model output is not treated as final until tool actions complete.
- Explicit capability contracts: tools are schema-described and invoked by name.
- Provider-neutral runtime events: streaming and tool lifecycle use shared types.
- Additive composition: command line interface and sub agent systems are built on the same core run loop.
- Configured execution surface: capabilities come from merged tool and agent configuration, not hidden defaults.
- Pragmatic observability: conversation entries are structured; detached sub agent runs can emit transcript logs.

## Documentation

- [Configuration](Docs/configuration.md)
- [Shell tools](Docs/shell-tools.md)
- [Sub agents](Docs/sub-agents.md)
- [Self tests](Docs/self-test.md)
- [Canned prompts](Docs/canned.md)

## License

Promptly is released under the MIT License. See [LICENSE](LICENSE).
