# Self Tests

Promptly includes built in self tests to validate configuration health, tool loading, and sub agent configuration. Each level makes at least one model call, so a working configuration and network access are required. These calls may incur provider usage costs.

## List available levels

```bash
promptly self-test list
```

Example output:

```
Level  Description
basic  Fast checks plus a short model conversation.
tools  Checks tool loading and invokes a tool through the model.
agents Checks sub agent configuration and runs a model-backed agent.
```

## Run self tests

```bash
promptly self-test basic
promptly self-test tools
promptly self-test agents
```

Each level performs these checks:

- `basic`: Loads the configuration and runs a short model conversation that includes a unique token and a required opening word.
- `tools`: Loads tool configurations, verifies include and exclude filtering, then asks the model to list the current working directory and report the current date and time using tools. The model summary must include the date/time output and at least one listed file name.
- `agents`: Creates a temporary agent configuration, runs the agent (which calls the model and returns a payload), then removes the temporary configuration.

Optional flags:

- `-c`, `--config-file`: Override the default configuration file path (default `~/.config/promptly/config.json`).
- `--tools`: Override the default tools configuration basename (default `tools`).

## Output format

Each run prints a structured JSON summary to standard output. Example:

```json
{
  "failedCount" : 0,
  "level" : "basic",
  "passedCount" : 3,
  "results" : [
    {
      "details" : null,
      "name" : "Configuration file exists",
      "status" : "passed"
    },
    {
      "details" : null,
      "name" : "Configuration loads",
      "status" : "passed"
    },
    {
      "details" : null,
      "modelOutput" : "Bright self test completed successfully. Token: 123e4567-e89b-12d3-a456-426614174000.",
      "name" : "Basic model conversation",
      "status" : "passed"
    }
  ],
  "status" : "passed"
}
```

Failures include a `details` message explaining the reason. Optional output fields (`modelOutput`, `toolOutput`, `toolOutputs`, `agentOutput`) appear when available. Self tests do not modify user content; temporary configuration and agent files are created under the system temporary directory and removed after each run.
