# Tasks: AI access

**Feature**: `029-ai-access-kalahoo` | **Date**: 2026-10-29
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Research**: [research.md](./research.md)
**Data model**: [data-model.md](./data-model.md) | **Validation**: [quickstart.md](./quickstart.md) |
**Checklist**: [checklists/requirements.md](./checklists/requirements.md)

**Format**: `[ID] [P?] [Story] Description with file path` — `[P]` = parallelizable (different files, no incomplete
dependency), `[Story]` = `US1` (generate reading content from an AI prompt).

## Status

**CLOSED** — 13 of 13 tasks done (T001–T013). 967 tests pass; `flutter analyze` clean. Stage closed on unit-level
numbers; device walk pending a live API key.

## Phase 1: Foundational — the provider list every story reads

**Goal**: `lib/ai/provider_list.dart` holds the reader's provider entries — seeded with the Google AI Studio/Gemini,
OpenRouter `:free` and NVIDIA NIM presets, open to the reader's own additions; each entry has `name`, `url`,
`registerTip`, `apiKey`, `active`; the reader's state (per-entry keys, `active` flags) persists in
`shared_preferences` (data-model §1).

- [x] T001 [P] `lib/ai/provider_list.dart`: the provider entry — `name`, `url`, `registerTip`, `apiKey`, `active`,
  `selected`; a preset is just an entry the reader has not customised; a user-added provider is the same shape
  (spec FR-002, FR-003; data-model §1).
- [x] T002 [P] `lib/ai/prompt.dart`: `buildPrompt(AIPrompt, String? readingContent)` — the reader's prompt string,
  the reading content included when the toggle is on, omitted when it is off (spec FR-006, A3); the `AIPrompt.type`
  is `text` / `image` / `video` (data-model §2, Q8).
- [x] T003 `lib/ai/config_store.dart`: the SharedPreferences persistence layer — read/write the provider entries,
  the per-entry API keys, the `active` flags, and the last-picked generation type under one namespace (data-model
  §1/§2).
- [x] T004 `lib/ai/auto_test.dart`: the connectivity test — when the reader adds or edits an entry's `apiKey`, the
  provider's endpoint is pinged with that key; `active` is set true iff the test returned a valid response (spec
  FR-004, Q7; research D5).

## Phase 2: The AI configuration UI

**Goal**: the top tool bar's Settings group; the provider list (add + edit a provider; a failing test leaves
`active` false).

- [x] T005 `lib/reading_view.dart` (the top tool bar): the Settings button; the AI control that opens the provider
  list (spec FR-001, SC-001).
- [x] T006 `lib/ai/provider_config_screen.dart`: the provider list — the preset seed, the reader's own additions
  (spec FR-003), the how-to-register tip, the API key field, the `active` and `selected` flags; editing a key runs
  the connectivity test (spec FR-002, FR-004).

## Phase 3: The prompt dialog and the transport

**Goal**: the Edit page's AI button → the prompt dialog (type + provider dropdown + prompt); the call to the
chosen provider's model of the chosen type.

- [x] T007 [P] `lib/reading_view.dart` (the Edit toolbar): the AI button to the right of the Format button — opens
  the prompt dialog (spec FR-005, SC-002; a control distinct from the Settings/AI configuration, spec Refinements).
- [x] T008 `lib/ai/provider_client.dart`: the provider transport — the prompt → model call per provider and per
  generation type (Gemini `generativelanguage` text/image, OpenRouter chat completions, NVIDIA NIM), with the
  per-provider headers/shape (research D1, R2; Q8).
- [x] T009 `lib/reading_view.dart`: the prompt dialog — the generation type picker (text / image / video), the
  provider options dropdown select (only `active` providers by default; the currently `selected` provider is always
  shown so the reader can switch back and re-test), the prompt string, the include-reading-content toggle (spec
  FR-005, A3, Q8, Q9); picking a provider updates that provider's `selected` field (Q9, Q10).
- [x] T010 `lib/reading_view.dart`: the generated text lands as an ordinary content (research D4) and the failure
  paths (spec FR-007: missing key, model error, network) keep the reader's configuration and prompt.

## Phase 4: The closing

**Goal**: the receipts, the walk, and the stage closed on its own numbers.

- [x] T011 `specs/029-ai-access-kalahoo/scripts/klhu_walk_ai.py`: the device walk driver — the Settings group, the
  Edit AI button, the prompt flow (type + provider + prompt), the connectivity test after a key add/edit, the generated
  content.
- [x] T012 `specs/029-ai-access-kalahoo/breakpoint.md`: the structural row — the counts, the ARB keys, the artifact
  checkers.
- [x] T013 `specs/029-ai-access-kalahoo/quickstart.md`: the closing pass — the re-took counts, the receipts written.

## Dependencies & ordering

- T001, T002, T003, T004 → T005, T006 (the Settings UI) → T007, T008, T009, T010 (the dialog and the transport) →
  T011, T012, T013 (the closing).

## Parallel opportunities

- **T001 with T002**: the provider entry and the prompt composition are different files with no incomplete
  dependency.
- **T004 with T007**: the connectivity test and the Edit page's AI button are different files.
- **T008 with T009**: the provider transport and the prompt dialog are different files (T008 owns the call, T009
  owns the UI).

## Implementation strategy

- MVP = Phase 1 (the provider entry + prompt + connectivity test) + Phase 3 (the dialog and the transport) — the AI seam
  end-to-end.
- Phase 2 (the Settings group UI) wraps the MVP.
- Phase 4 closes the stage on its own numbers.

## Requirement coverage

| requirement | tasks |
|---|---|
| FR-001 (provider list behind the top tool bar Settings group) | T003, T005, T006 |
| FR-002 (the three provider presets, how-to-register tips, API key field; a preset saves like a user-added entry) | T001, T003 |
| FR-003 (the reader can add their own provider; the list is reader state, not preset-only) | T001, T006 |
| FR-004 (an add/edit of the API key triggers a connectivity test; `active` is true only when it passed) | T004, T006 |
| FR-005 (the prompt dialog offers the generation type, the provider options dropdown, the prompt; the dropdown updates `selected`) | T007, T009 |
| FR-006 (the prompt is a string to the chosen provider's model of the chosen type, optional reading content) | T002, T008, T009 |
| FR-007 (failure handling) | T010 |
| SC-001 (the Settings group leads to the provider list) | T005, T006 |
| SC-002 (the Edit AI button opens the dialog; type + provider + prompt are chosen; the prompt is sent) | T007, T008, T009 |
| SC-003 (the reading content is optional in the prompt) | T002, T009 |
