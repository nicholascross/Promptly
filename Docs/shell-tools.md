# Shell tools

## Overview

Promptly can expose allow-listed shell commands as tools. Tools are configured in JSON files and only run when loaded and allowed by the current tool filters.

## Configuration files

- `tools.json` in the current working directory.
- `~/.config/promptly/tools.json` in the configuration directory.
- `--tools <basename>` to override the default tools file basename.

## Loading and filtering

- `--include-tools <substring>` loads tools whose names include the substring. This also enables tools marked as opt-in.
- `--exclude-tools <substring>` removes tools whose names include the substring.

Promptly runs tools based on natural language instructions in the message body rather than explicit command flags.

## Tool management commands

```bash
promptly tool list
promptly tool view <tool-id>
promptly tool add --id <id> --name \"<description>\" --command \"<executable>\"
promptly tool install [--tools <basename>]
promptly tool remove <tool-id> [--force] [--config-file <path>]
```

## Tool schema

Each entry may include:

- `name`: Unique identifier for the tool.
- `description`: Human-readable description of the command's purpose.
- `executable`: Path or name of the executable to invoke.
- `argumentTemplate`: Array of arrays of strings, where each subarray represents a group of tokens (flags and placeholders) to include together. Placeholders of the form `{{paramName}}` or `{(paramName)}` are replaced with provided parameter values. If any placeholder in a group is missing, the entire subarray is omitted to prevent partial flags without values. Use `{(paramName)}` for parameters representing file or directory paths; these values are validated to reside within the project sandbox.
- `parameters`: A JSON Schema object describing the allowed parameters, their types, and required or optional status.
- `echoOutput` (optional): When true, stdout and stderr of the command are echoed directly.
- `truncateOutput` (optional): When true, large outputs are truncated via log slicing (retaining head and tail lines and reinjecting regex matches).
- `exclusiveArgumentTemplate` (optional): When true, `argumentTemplate` groups are treated as alternatives; Promptly uses only the first group whose placeholders can be fully resolved.
- `optIn` (optional): When true, the tool is disabled by default and only loaded when its name matches a substring in `--include-tools`.

Note: Order argument template groups from most specific to most general (for example, chunked tail and head first, full-file fallback last).

## Example

```json
{
  "name": "ShowFileTree",
  "description": "Visual directory tree listing",
  "executable": "tree",
  "truncateOutput": true,
  "argumentTemplate": [["{(path)}"]],
  "parameters": {
    "type": "object",
    "properties": {
      "path": { "type": "string", "description": "Directory path to list" }
    },
    "required": ["path"],
    "description": "Parameters for tree command"
  }
}
```

## Related docs

- [Configuration](configuration.md)
- [Default tools reference](tools.json)
