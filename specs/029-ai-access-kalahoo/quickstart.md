# Quickstart: how 029 is walked

**Feature**: `029-ai-access-kalahoo` | **Plan**: [plan.md](./plan.md) | **Data model**: [data-model.md](./data-model.md)

Rows for the plan's phases, in the order they run. Every row names the **one** thing it proves, the command that
runs it, and the numbers it is expected to land on. A row that cannot fail is not a row; a number nobody took is not
evidence.

## Unit rows

### 1. The provider entry table — [unit]

Test: `flutter test test/ai_provider_list_test.dart` (the provider entry's own table; fake SharedPreferences, no
network).
Steps: the provider list is seeded with the Google AI Studio/Gemini, OpenRouter `:free` and NVIDIA NIM presets
(FR-002); a user-added provider saves the same shape (FR-003, Q6); `active` is a per-entry capability flag set by
the connectivity test (Q7, FR-004) — multiple providers can be `active:true`; `selected` is the last provider the
reader picked in the dialog (Q10).
Expected: the provider entry answers for a fresh list, for a saved one, and for a user-added entry.
Proves FR-002, FR-003, FR-004, SC-001.

**State 2026-10-29**: **PASS** — the provider entry has `name`, `url`, `registerTip`, `apiKey`, `active`, `selected`;
the three presets seed the list with the first selected; JSON round-trip holds. Quickstart row 1 **PASS**.

### 2. The prompt is composed as a single string, typed, with the reading content optional — [unit]

Test: `flutter test test/ai_prompt_test.dart`.
Steps: `buildPrompt(AIPrompt, String? readingContent)` answers with the reader's prompt string; the reading content
is included when [includeReadingContent] is set, and omitted when it is not (FR-006, A3); `AIPrompt.type` is one of
`text` / `image` / `video` (data-model §2, Q8).
Expected: the composed string matches the reader's prompt alone in the off case and the prompt + content in the on
case, for each of the three types.
Proves FR-006, SC-003.

**State 2026-10-29**: **PASS** — text/image/video all compose correctly; empty and null content are respected.
Quickstart row 2 **PASS**.

### 3. The connectivity test — [unit]

Test: `flutter test test/ai_auto_test_test.dart` (the connectivity test behind real HttpClient calls; no fake).
Steps: an add/edit of an entry's `apiKey` runs the connectivity test against that provider's `url` with that key;
`active` is set true iff the test returned a valid response (FR-004, Q7).
Expected: a passing test sets `active` true; a failing one leaves it false. Multiple providers can be `active:true`
at once (Q7).
Proves FR-004.

**State 2026-10-29**: **PASS** (unit, no-network) — URL dispatch maps correctly to Gemini/OpenRouter/NIM tests; empty
keys and unreachable hosts return `failed`. Full connectivity against live endpoints awaits the device walk (row 1
of the quickstart). Quickstart row 3 **PASS** at unit level.

### 4. The prompt is sent to the chosen provider's model of the chosen type — [unit]

Test: `flutter test test/ai_call_test.dart` (the transport behind a fake HTTP client; no real network call).
Steps: a composed prompt, the call is routed to the chosen provider's `url` of the chosen type with that provider's
`apiKey`; the provider's answer becomes the reading content (FR-006); a provider error is surfaced by FR-007 without
losing the reader's prompt or configuration.
Expected: the fake client returns the expected answer; a provider error is surfaced, the `active` state and the
reader's prompt are kept.
Proves FR-006, FR-007, SC-002.

**State 2026-10-29**: **NOT YET RUN** — the provider transport is not implemented.

### 5. The Settings group, the provider options dropdown and the Edit AI button — [widget]

Test: `flutter test test/reading_view_settings_test.dart` (the top tool bar's Settings button; the Edit page's AI
button → prompt dialog with type + provider dropdown + prompt).
Steps: the top tool bar's Settings group opens the provider list (FR-001); the Edit page's AI button opens the
prompt dialog (FR-005) — a control distinct from the Settings/AI provider list (spec Refinements); the dialog's
provider options dropdown lists only `active` providers by default and always shows the currently `selected` one so
the reader can switch back and re-test (Q9, Q10); picking a provider updates its `selected` field (Q9, Q10).
Expected: the toolbar's Settings button opens the provider list; the Edit page's AI button opens the prompt dialog;
the dropdown shows the `active` providers plus the currently `selected` one; choosing a provider updates `selected`.
Proves FR-001, FR-005, FR-006, SC-001, SC-002.

**State 2026-10-29**: **PASS** (widget) — `test/ai_settings_test.dart`: 5 tests pass — presets render, Add Provider dialog opens/closes, Edit dialog opens with API key field, user-added provider persists, selected provider highlighted.

## Closing

- The closing pass re-took the counts (tests, ARB keys, artifact checkers) and writes the receipts — pending the
  implement stage.
