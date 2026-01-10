# Sub agents

## Overview

Sub agents are named configurations that run specialized prompts and tools on behalf of a supervising session. They are useful for isolating workflows and keeping tool access scoped to a specific agent configuration.

## Routing guidance

- Use sub agents for multi step work, multi file changes, or specialized workflows.
- Prefer direct file reads or search tools for small lookups and single file questions.
- Avoid sub agents when the request can be completed with a single command or a short explanation.
- Ask clarifying questions before invoking a sub agent when the request is ambiguous.
- When you use a sub agent, provide a clear task statement along with explicit goals and constraints.

## Configuration location

Sub agent configuration files live under the agents directory relative to the configuration file path (for example `~/.config/promptly/agents`).

## Commands

```bash
promptly agent list
promptly agent view <name>
promptly agent add <name> \
  --agent-name "Refactor Agent" \
  --description "Refactor code while preserving behavior." \
  --system-prompt "You are a refactoring specialist."

promptly agent install
promptly agent remove <name> [--force] [--config-file <path>]
```

## Related docs

- [Self tests](self-test.md)
- [Configuration](configuration.md)
