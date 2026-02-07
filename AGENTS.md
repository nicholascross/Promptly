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
- When you introduce a new canned prompt, define it in `Sources/PromptlyKit/Canned/DefaultCannedPrompts.swift`, mirror the text in `Docs/canned.md`, and refresh references in the documentation as needed.

### 4. Validation Guidance
- When documenting example workflows, prefer commands that can run safely in diverse environments (avoid destructive defaults; require opt-in tools for changes).

### 5. Architecture and Testing Principles
- Favor additive changes: introduce new types alongside existing code, then migrate callers after characterization tests lock in behavior.
- Preserve behavior for Responses and Chat Completions surfaces when refactoring core flows.
- Keep application programming interface data transfer objects defined with Codable; avoid ad hoc JavaScript Object Notation lookups.
- Keep PromptlyKit core policy-light; move Promptly-specific defaults into higher-level modules.
- Add protocol seams only at boundaries needed for testing or reuse; avoid unnecessary abstraction.
- Use Swift Testing and prefer deterministic tests without network access or time-based flakiness, using fake transports and tool execution boundaries.

### 6. Updating This Document
- At the end of each work session, automation agents should review any new constraints or patterns they discovered and append concise guidance here.
- When adding entries, favor actionable instructions over historical summaries, and keep the document focused on reusable lessons.
- If a change affects existing guidance, update or consolidate the relevant sections rather than duplicating information.

### 7. Release Workflow
- The `update-homebrew` GitHub Action runs on `macos-latest`, ensuring TerminalUI’s Darwin dependency links successfully.
- It includes an explicit `swift-actions/setup-swift` step (6.0.3) plus `swift build`; keep both so releases fail fast when the project does not compile.

### 8. Moving Utilities
- When moving shared types into `PromptlyKitUtils`, add target dependencies and imports in every module that uses them (including scripts and tests).
- Ensure any utility types referenced across targets are declared `public` in `PromptlyKitUtils`.

### 9. Streaming Responses Events
- The server-sent events parser should flush after each data line because the Responses API delivers single-line JSON payloads without blank line separators.

### 10. Public PromptlyKit Types
- Keep PromptlyKit public types under `Sources/PromptlyKit/Public` to make the public surface area obvious.

### 11. Internal PromptlyKit Types
- Keep PromptlyKit internal types under `Sources/PromptlyKit/Internal` for consistent layout.

### 12. Public Message Models
- Use provider-agnostic `PromptMessage` types in the public API, and keep provider-specific chat models under `Sources/PromptlyKit/Internal/Models/Chat`.

### 13. Assistant Output
- `PromptRunResult` no longer includes `finalAssistantText`; rely on `conversationEntries` and streamed events for assistant output.
- Endpoints must emit `assistantTextDelta` for completed responses even when streaming does not produce deltas, so callers receive assistant text consistently.

### 14. Sub Agents
- Sub agent configuration files live under `~/.config/promptly/agents` and inherit defaults from the base configuration.
- Sub agents are exposed as tools and must return via a dedicated return tool; exclude sub agent tools from sub agent tool lists to prevent recursion.
- Sub agent tool selection defaults to the supervising session tool file name and include and exclude lists, unless the agent configuration overrides them.
- Log full transcripts by convention and return only a compact summary payload to the supervisor.
- Sub agent message assembly uses a generic system prompt plus the agent system prompt, and a single user message that includes the task, goals, constraints, and context pack; return the first `ReturnToSupervisor` payload.
- Use a progress tool for out-of-band status updates; emit updates to the tool output stream and logs, not the supervisor message history.
- Resolve the agents directory relative to the resolved config file path; specified values replace inherited ones, and empty arrays clear inherited arrays.
- Provide `promptly agent` management commands similar to tool management, and add a PromptlySelfTest module with command support for basic, extended, and sub agent self tests.
- Use `agent.name` for sub agent tool naming; prefix progress output with `[sub-agent:<agent-name>]`; keep self test commands as explicit subcommands without aliases.
- Ensure sub agent tool names follow provider tool name constraints (letters, numbers, underscores, hyphens only); avoid dots or other punctuation that fails `^[a-zA-Z0-9_-]+$`.
- Treat resume identifiers that are not universally unique identifiers (UUIDs) as absent, and only error on unknown UUID resume identifiers.

### 15. Self Test Behavior
- Self tests should make real model calls at each level so operators can confirm provider connectivity.
- Tools-level self tests should invoke a safe, read-only tool such as listing the current directory through the model tool call path.
- Agents-level self tests should create, run, and remove a temporary agent configuration under a temporary directory to avoid mutating user content.
- When generating temporary self test tool configurations, use absolute tools file paths so include filters resolve to available tools.
- Self test supervisor resume checks should treat only valid UUID values as continuation handles; placeholder strings such as `omit`, `none`, or `/dev/null` are considered missing handles.

### 16. Testing Credentials
- Prefer injecting a `CredentialSource` in tests instead of mutating process environment variables.

### 17. Memory System
- Memory tools should be always available by default.
- Default memory store location should live under the configuration directory, with a configuration override for a different directory.
- Project scope resolution should prefer the repository root when present.
- The memory librarian sub agent can use a read only search tool backed by ripgrep to scan the file system store.
- Include and exclude tool filters should apply to memory tools as well.
- Memory store layout should place entries under status specific subdirectories for active, superseded, and archived entries.
- Memory lifecycle should supersede on updates, archive only on explicit request or policy, and remove only on explicit request.
- Use catalog first for listing memory entries; return metadata only for list operations.
- Recall should be query based only; identifiers are not accepted for recall requests.
- List responses should include identifiers for management operations.
- Scope resolution should derive keys from configuration and working directory paths, with `memory.storeDirectory` and `memory.projectIdentifier` configuration overrides.
- Memory tool documentation should include JavaScript Object Notation schema examples for request and response payloads.
- Memory librarian guidance should spell out store, recall, archive, and remove workflows.
- Memory defaults should set list and recall limits, enforce a recall size cap, rebuild the catalog on missing or decoding errors, and define percent encoding for scope key directory names.
- Memory tool errors should use a structured error payload with a code and message.

### 18. Bundled Resources
- Prefer loading bundled resources through `Bundle.module`, with a fallback lookup relative to the executable when the bundle is missing.
- When bundled resources are missing, optional features should degrade gracefully instead of failing the entire command.
- Homebrew installs should place the resource bundle alongside the executable (for example, under `libexec`) with a symlink in `bin`.
- Support `PROMPTLY_RESOURCE_BUNDLE` as an override to point to a resource bundle directory.
- Bundle canned prompts, default agents, and default shell tools by default.
- Use `PromptlyAssets` types like `BundledResourceLoader` and `BundledDefaultAssetPaths` for default assets so missing bundles do not crash the process.
- Canned prompts load from bundled assets on demand; there is no install command for canned prompts.

### 19. Tool Listing
- Include built-in tools in tool listings; they are not defined in tools configuration files and should be represented explicitly.
- Built-in tool names take precedence over tools configuration entries when listing to match runtime loading behavior.

### 20. Sub Agent Return Contract
- Sub agents must not ask the user questions directly; they should return via ReturnToSupervisor with needsMoreInformation and requestedInformation when input is required.
- If the return payload is missing, issue a short reminder prompt to call ReturnToSupervisor and retry before falling back, with a bounded number of attempts.
- If the return payload is still missing, return a minimal payload that marks needsSupervisorDecision, includes decisionReason, and provides a supervisorMessage with role user and the last assistant response while logging missing_return_payload.

### 21. Argument Template Placeholders
- Treat empty string or null values for single-placeholder template tokens as missing so optional flag groups are omitted.
- Keep embedded placeholders (within longer strings) unchanged so empty substitutions remain possible when intended.

### 22. Sub Agent Preference
- Prefer sub agent tools over shell command tools when a supervisor hint matches the request; list sub agent tools before shell tools and reinforce the preference in supervisor hints.

### 23. Supervisor Resume Plumbing
- Preserve ReturnToSupervisor tool outputs in supervising conversation state so resume identifiers are available for follow up tool calls without user re-entry.

### 24. Agent Configuration Hygiene
- Avoid writing empty strings for optional agent configuration overrides (model, provider, tools file name). Treat empty strings and nulls as absent when merging overrides.

### 25. Naming and Abbreviations
- Avoid unnecessary abbreviations, but keep common terms like API and URL in their standard short form.

### 26. Skill Packaging Dependencies
- When PyYAML is unavailable in restricted environments, use a local Python shim on PYTHONPATH to satisfy quick_validate and package_skill scripts.

### 27. Detached Task Logging
- Use `DetachedTaskTranscriptLogSink` for sub agent transcript logging; do not keep a separate `SubAgentTranscriptLogger`.
- Treat progress updates as tool call events in logs rather than introducing a dedicated `progress_update` event.

### 28. Supervisor Resume Recovery Runner
- Keep supervisor follow up resume recovery logic centralized in `PromptlySubAgents` through `SubAgentSupervisorRunner` and `SubAgentSupervisorRecovery`.
- Route `prompt`, `ui`, `agent run`, and self test supervisor flows through the shared runner instead of duplicating per interface recovery checks or prompts.

Following these conventions keeps Promptly’s automation surface predictable and safe for both human operators and LLM agents. Edit this file whenever fresh insights arise so future contributors inherit the full context.
