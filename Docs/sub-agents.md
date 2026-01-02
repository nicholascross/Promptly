# Sub agents

## Overview

Sub agents are named configurations that run specialized prompts and tools on behalf of a supervising session. They are useful for isolating workflows and keeping tool access scoped to a specific agent configuration.

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
