# PromptlyKit Transition Plan (Session/Event Architecture)

This document is an engineering plan for internal development and is not required for day-to-day CLI usage.

## Goals

- Preserve existing behavior for both API surfaces: Responses and Chat Completions.
- Keep Codable DTOs for all API communication; avoid ad-hoc JSON lookups.
- Make unit testing a first-class concern using **Swift Testing** (not XCTest).
- Improve cohesiveness and reuse by separating core framework concerns from Promptly-specific defaults.
- Keep the design small and understandable (KISS), remove duplication (DRY), and use protocol seams where they directly enable testing or reuse (SOLID without over-engineering).

## Non-Goals

- Adding new providers or features during the transition (unless required to preserve behavior).
- Refactoring the CLI application module (outside `PromptlyKit`) beyond what is needed to adopt the new core API.
- Rewriting API DTOs or switching to dynamic JSON parsing.

## Guiding Principles

- **Additive first, replacement last:** introduce new types alongside existing code, then migrate callers once covered by tests.
- **Characterize before changing:** lock in existing behavior with tests before refactoring.
- **Prefer seams at boundaries:** add protocols primarily at I/O boundaries (HTTP transport, token lookup, tool execution, output streaming).
- **Core is policy-light:** core should expose hooks; Promptly-specific policy (tool catalogs, builtin tools, log slicing) lives in a higher-level module.

## Current Baseline (for reference)

- `PromptRunCoordinator` selects an `AIClient` implementation via `AIClientFactory`.
- Two streaming implementations exist: `ResponsesAIClient` and `ChatCompletionsAIClient`.
- Tools are executed via an injected closure assembled in `PromptRunCoordinator`.
- Tool configuration + optional middleware is assembled by `ToolFactory`.

## Target Architecture (high level)

- **Coordinator:** validates config, selects endpoint, builds transport and tooling gateway, starts a session stream.
- **Session runner:** drives multi-turn looping, tool iteration limits, phase events, and uniform error wrapping.
- **Unified event stream:** a single `PromptStreamEvent` type for assistant deltas, tool calls/results, transcript commits, and failures.
- **Transcript accumulator:** deterministic transcript materialization from the event stream (including tool-output tombstoning policy hook if needed).
- **Tooling gateway:** injected tool execution boundary; default implementation can implement approval and dispatch in higher layers.

## Phased Migration

### Phase 1 — Swift Testing baseline and characterization tests

**Intent:** lock in existing behavior and create test seams without changing behavior.

**Work**
- Add `PromptlyKitTests` using **Swift Testing**.
- Add fixtures and characterization tests around:
  - Request encoding: `ResponsesRequestFactory`, `ChatCompletionsRequestFactory`.
  - Streaming parsers/collectors: `ResponseStreamCollector`, `ChatCompletionsResponseProcessor`.
  - DTO decoding: `ToolCall`, `APIResponse` error handling.
  - Message encoding quirks that must remain stable during transition.

**Acceptance**
- Tests run deterministically and do not require network.
- No production behavior changes.

---

### Phase 2 — Minimal I/O abstractions for testability

**Intent:** allow unit tests to fully exercise request/response logic without real `URLSession` and without stdout side effects.

**Work**
- Introduce a small `HTTPTransport` abstraction (or a `URLSession` wrapper protocol) supporting both:
  - request/response (`data(for:)`)
  - streaming (`bytes(for:)`)
- Default implementation wraps `URLSession.shared`.
- Inject transport into:
  - `ResponsesClient`
  - `ChatCompletionsAIClient` (or its request sender)

**Acceptance**
- Existing clients behave identically with the default transport.
- Unit tests can simulate both success and error cases for both APIs.

---

### Phase 3 — Unified event stream (provider-neutral)

**Intent:** create a reusable output surface that does not assume stdout printing or a specific UI.

**Work**
- Introduce `PromptStreamEvent` (or equivalent) to represent:
  - assistant text deltas
  - tool call requested
  - tool result produced
  - transcript committed (optional in early step)
  - failure (typed error)
- Make this additive: keep existing `AIClient` and `PromptRunCoordinator` APIs operational.

**Acceptance**
- New event stream can be unit tested with fake transports and fake tool gateways.
- Existing behavior and DTOs remain unchanged.

---

### Phase 4 — Run executor + conversation recorder

**Intent:** centralize multi-turn orchestration and transcript formation in one place.

**Work**
- Add `PromptRunExecutor`:
  - multi-turn looping
  - tool iteration limits
  - consistent error wrapping and termination behavior
- Add `PromptConversationRecorder`:
  - deterministic conversation entry commits from events
- Add `ToolingGateway` protocol as the tool execution boundary (no approvals in core).

**Acceptance**
- Run behavior can be tested without real HTTP or real tools.
- Transcript commits are deterministic and stable.

---

### Phase 5 — Adapter endpoints for Responses and Chat Completions

**Intent:** preserve current provider implementations while consolidating orchestration.

**Work**
- Implement provider adapters (endpoint interfaces) that use existing Codable DTOs:
  - `ResponsesEndpoint` uses `ResponsesRequestFactory`, `ResponsesClient`, `ResponseStreamCollector`.
  - `ChatCompletionsEndpoint` uses `ChatCompletionsRequestFactory`, `ChatCompletionsResponseProcessor`.
- Update `PromptRunCoordinator` to delegate to the run executor using the selected endpoint adapter.
- Keep the existing `AIClient` surface intact until the new surface proves stable.

**Acceptance**
- Phase 1 characterization tests still pass unchanged.
- New tests verify that both providers produce equivalent event/transcript semantics for common scenarios.

---

### Phase 6 — Split policy-heavy defaults out of PromptlyKit core

**Intent:** make `PromptlyKit` a reusable foundation; move Promptly-specific behavior to a separate module.

**Work**
- Define a separate target/module (example name): `PromptlyKitDefaults` or `PromptlyAgentKit` (final naming TBD).
- Move policy-heavy components out of core, keeping only hooks in core:
  - tool catalog file loading/merging (today in `ToolFactory`)
  - builtin tools selection (for example `ApplyPatchTool` default inclusion)
  - log slicing middleware (`LogSlicingTool`) and its model-backed helper (`SuggestionService`)
- Keep `ExecutableTool`, schemas, and the `ToolingGateway` protocol in core.

**Acceptance**
- Core `PromptlyKit` has minimal dependencies and minimal policy.
- Higher-level modules can replicate today’s CLI behavior by composing core + defaults.

## Testing Strategy (Swift Testing)

- Prefer deterministic tests that run without network and without time-based flakiness.
- Use fake transports and fake tooling gateways to:
  - replay streaming sequences
  - simulate tool call cycles
  - validate iteration limit behavior and transcript results
- Keep DTO tests strongly typed: assert encoded/decoded DTO values rather than probing JSON.

## Risks and Mitigations

- **Risk:** subtle behavior drift between Responses and Chat Completions flows.
  - **Mitigation:** characterization tests + adapter tests that compare event/transcript semantics.
- **Risk:** over-abstraction that complicates the core.
  - **Mitigation:** introduce protocols only at boundaries needed for tests/reuse; default implementations remain straightforward.
- **Risk:** Promptly-specific policy leaks into core.
  - **Mitigation:** explicitly split “core hooks” vs “defaults module” during Phase 6.

## Deliverables Summary

- A tested, provider-neutral session framework (core `PromptlyKit`) with:
  - endpoint adapters for Responses and Chat Completions
  - unified stream events
  - deterministic transcript accumulation
  - tooling gateway abstraction
- A follow-on module (Agent kit) that composes on top of core without pushing policy into the foundation.

## Worklog

Add short entries as work progresses to keep context and decisions discoverable.

- Status: Created initial transition plan and phased architecture outline.
- Status: Phase 1 started: added `PromptlyKitTests` using Swift Testing and created initial characterization tests for request factories, streaming processors, and core DTO decoding.
- Status: Phase 2 started: added a minimal `NetworkTransport` abstraction and injected it into streaming and request/response paths to enable deterministic unit tests without real `URLSession`.
- Status: Phase 3 started: added a provider-neutral `PromptStreamEvent` type as the foundation for a unified event stream API.
- Status: Phase 4 started: added `PromptEndpoint`, `ToolExecutionGateway`, and an initial `PromptRunExecutor` with unit tests (not yet wired into existing provider clients).
- Status: Phase 5 started: added provider endpoint adapters (`ResponsesPromptEndpoint`, `ChatCompletionsPromptEndpoint`) and an additive `PromptRunCoordinator` entry point to run prompts via the new runner.
- Status: Phase 6 started: split tool catalog loading and tool construction (`ToolFactory`) into a new target `PromptlyKitTooling`, keeping core `PromptlyKit` more policy-light.
- Status: Phase 6 continued: moved log slicing middleware (`LogSlicingTool`) and model-backed pattern suggestion (`SuggestionService`) into `PromptlyKitTooling`.
- Status: Added endpoint adapter unit tests for `ResponsesPromptEndpoint` using a fake `NetworkTransport` to simulate SSE streaming and tool-call turns.
- Status: Added provider-neutral `PromptConversationRecorder` with Swift Testing unit tests to build deterministic conversation entries from `PromptStreamEvent`.
- Status: Updated `promptly` executable to run prompts via `PromptRunCoordinator` (new run executor/event stream path) in both standard and terminal UI modes, exercising the new architecture end-to-end.
- Status: Removed temporary Responses debugging logs and simplified the Responses endpoint adapter; Swift Testing suite remains green.
