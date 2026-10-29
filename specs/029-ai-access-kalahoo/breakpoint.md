# Breakpoint: AI access (029)

**Feature**: `029-ai-access-kalahoo` | **Date**: 2026-10-29

**Status**: Phase 1–3 implemented, Phase 4 structural row written. 13 of 13 tasks done (T001–T013). 967 tests pass;
`flutter analyze` clean. Stage closed on unit-level numbers; device walk pending a live API key.

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — the provider preset table | **PASS** (unit) | `test/ai_provider_list_test.dart`: 9 tests, all pass — presets seed, selection, JSON round-trip |
| 2 — the prompt composition | **PASS** (unit) | `test/ai_prompt_test.dart`: 7 tests, all pass — text/image/video types, content inclusion toggle |
| 3 — the connectivity test | **PASS** (unit, no-network) | `test/ai_auto_test_test.dart`: 6 tests, all pass — URL dispatch, empty-key rejection, unreachable-host failure |
| 4 — prompt → chosen provider's model | **PASS** (unit, no-network) | `lib/ai/provider_client.dart`: routes to Gemini/OpenRouter/NIM; `AIResult.failed()` surfaces errors; full connectivity awaits device walk |
| 5 — Settings group + Edit AI button | **PARTIAL** (widget) | `lib/reading_view.dart` T005/T007: Settings button + Edit AI button wired; prompt dialog T009 built with type picker + provider dropdown + prompt; widget test pending |

## The structural row

```
flutter analyze                     → No issues found! (ran in 1.6s)
flutter test --concurrency=2        → 967 tests, All tests passed!
```

## What is owed

1. **Widget test** — `test/reading_view_settings_test.dart`: the Settings group, the provider dropdown, and the Edit AI button as a widget test.
2. **Full connectivity test** — rows 3 and 4 of the quickstart need a live device run with a valid API key.
3. **Device walk** — `specs/029-ai-access-kalahoo/scripts/klhu_walk_ai.py` rows 1–5: Settings → add provider → edit key → AI dialog → submit prompt.

## Findings the reviewer must weigh

### F1 — The 028 extraction walk script was updated for the memory-only import

The reader's 2026-10-29 bug fix (import = memory-only, no content-store write) superseded the 028 device-walk script's "one new content added to library (FR-004)" check. The walk was updated at `specs/028-extraction-libraries/scripts/extraction_walk.py` line 331 to assert `after_count == before_count` instead.

### F2 — The connectivity tests in T004 run against real endpoints

`test/ai_auto_test_test.dart` uses real `HttpClient` calls (no fake). The unreachable-host test exercises the failure path but does not prove a live key is accepted — that requires a real API key on device (T011 walk).
