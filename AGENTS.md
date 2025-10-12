## Promptly Agent Guidelines

These notes capture the best practices learned while extending Promptly’s toolset and canned prompts. They exist to help future automation agents (and contributors) avoid rediscovering the same constraints.

### 1. Shell Tool Definitions
- Model optional behavior with **separate argument-template rows** and, when only one should apply at a time, add `.exclusiveArgs()`. Do not rely on boolean parameters—templates only substitute strings.
- Gate anything that mutates state (`rm`, `git add`, `git commit`, etc.) behind `.optedIn()` so the tool stays disabled unless explicitly included.
- Prefer descriptive names (`GitDiffRange`, `SwiftLintAutocorrectFile`) and keep command descriptions agnostic of Promptly itself; explain *what* happens, not *who* runs it.

### 2. Interaction Style
- Promptly executes shell tools through **natural-language instructions**, not direct CLI flags like `--tool`. All examples, canned prompts, and docs must phrase actions conversationally (e.g., “Let’s check the repository status for the current project” rather than naming the specific command).
- When demonstrating workflows, include the relevant tool names with `--include-tools …` only to expose the tools, then describe the desired outcome in the message body.

### 3. Canned Prompts
- Keep the bundled canned prompts installed: `promptly canned install` (add `--overwrite` to refresh). When you introduce a new canned prompt, define it in `Sources/PromptlyKit/Canned/DefaultCannedPrompts.swift`, mirror the text under `Docs/canned/`, and refresh references in the documentation as needed.

### 4. Validation Guidance
- When documenting example workflows, prefer commands that can run safely in diverse environments (avoid destructive defaults; require opt-in tools for changes).

### 5. Installing Defaults
- Default shell tools: `promptly tool install [--tools <basename>]`.
- Default canned prompts: `promptly canned install [--overwrite]`.

### 6. Updating This Document
- At the end of each work session, automation agents should review any new constraints or patterns they discovered and append concise guidance here.
- When adding entries, favor actionable instructions over historical summaries, and keep the document focused on reusable lessons.
- If a change affects existing guidance, update or consolidate the relevant sections rather than duplicating information.

Following these conventions keeps Promptly’s automation surface predictable and safe for both human operators and LLM agents. Edit this file whenever fresh insights arise so future contributors inherit the full context.
