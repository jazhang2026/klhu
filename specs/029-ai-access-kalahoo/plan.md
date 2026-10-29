# Implementation Plan: AI access

**Branch**: `029-ai-access-kalahoo` | **Date**: 2026-10-29 | **Spec**: [specs/029-ai-access-kalahoo/spec.md](specs/029-ai-access-kalahoo/spec.md)

**Input**: Feature specification from `/specs/029-ai-access-kalahoo/spec.md`

## Summary

Add the reader's first AI access (spec 029): an AI provider list — seeded with the Google AI Studio (Gemini), OpenRouter (17 `:free` models) and NVIDIA NIM presets, and open to the reader's own additions — behind the top tool bar's Settings group. Each provider entry carries a `name`, a `url`, a how-to-register tip, an API key field and an `active` flag that turns on only after the connectivity test that follows an add/edit of the API key. The AI button on the Edit page (a control distinct from the Settings/AI provider configuration one) opens the AI prompt dialog, which offers a generation type (text / image / video), a provider options dropdown of the `active` providers, and the prompt string. The prompt is sent to the chosen provider's model of the chosen type, with the reading content optionally included.

## Technical Context

**Language/Version**: Dart 3.13.4 (Flutter 3.47.5); single Flutter/Dart codebase (constitution I).

**Primary Dependencies**: `shared_preferences` ^2.5.5 for the AI provider list (entries: `name`, `url`, `registerTip`, `apiKey`, `active`) and for the generation type the reader last picked; an HTTP client for provider REST calls (Gemini `generativelanguage`, OpenRouter chat completions, NVIDIA NIM). No backend, no account (constitution IV).

**Storage**: Local only — SharedPreferences for the provider list and the last-picked generation type. No server-side storage.

**Testing**: `flutter_test` — widget tests (top tool bar Settings → AI provider list; add a provider; edit a key → connectivity test; the `active` flag set only on a passing test; the Edit page AI button → prompt dialog with type + provider dropdown + prompt; provider dropdown updates `selected`); unit tests (prompt assembly with optional reading content; the connectivity test; provider failure handling).

**Target Platform**: iOS 16+, Android 10+ (API 29+) — per constitution constraints.

**Project Type**: Mobile app (Flutter).

**Performance Goals**: AI calls are user-initiated (Edit → AI); app-side latency is dialog/UI only; no read-pipeline performance gate (AI runs outside the read).

**Constraints**: Flutter stable / Dart; single codebase (no platform forks); network use declared in spec (constitution IV, A2); test-first (constitution III); YAGNI (constitution V).

**Scale/Scope**: Single-reader app; v1 = preset + user-added provider list, active-only selection, one prompt-driven content generation per submission.

## Constitution Check

- **I. Flutter Single Codebase**: pass — AI code lives in the shared Dart codebase.
- **II. Spec-Driven**: pass — spec 029 carried through three review rounds; this plan follows it.
- **III. Test-First**: pass — plan assumes tests-first implementation.
- **IV. On-Device First**: pass-with-declaration — AI is a network call (declared in spec).
- **V. Simplicity**: pass — three presets only; YAGNI respected.

## Project Structure

### Documentation (this feature)

```text
specs/029-ai-access-kalahoo/
├── plan.md              # This file
├── spec.md              # The approved-through-review spec
└── tasks.md             # Phase 2 output (/speckit-tasks; not created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── ai/                  # NEW — AI access (029): provider list/presets, config, prompt → model call, connectivity test
├── reading_view.dart    # AI button (Edit, right of Format) → AI prompt dialog; selected provider
├── services/            # existing content store etc.
tests/
├── ai_*.dart            # NEW — AI provider list, prompt, dialog, connectivity test tests
```

**Structure Decision**: AI access is a small provider seam in `lib/ai/` mirroring the existing document-extractor/ocr seam pattern (capability behind a seam, platform/hosted client implementation); the reading view wires the Edit-page AI button and prompt submission; the top tool bar Settings group hosts the provider configuration UI.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|-----------|------------|-------------------------------------|
| None | — | — |
