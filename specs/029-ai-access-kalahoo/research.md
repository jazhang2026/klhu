# Research: AI access — what the tree carries, and the readings this plan takes

**Feature**: `029-ai-access-kalahoo` | **Date**: 2026-10-29 | **Spec**: [spec.md](./spec.md)

## Baseline, measured on the checkout this plan starts from

```
flutter analyze                     → No issues found!
flutter test --concurrency=2        → 931 tests, All tests passed!
```

## §1 What the tree already carries (the evidence the requirements rest on)

| need | where | what it answers |
|---|---|---|
| the top tool bar | `lib/reading_view.dart` (`_pageActions`, ~L600–640) | the reader's own actions — appearance, contents, import, text type, play/stop; a Settings button groups them |
| the Edit surface | `lib/reading_view.dart` (`_enterEdit`, ~L784; the edit toolbar ~L3300) | the Edit page's own buttons (Save/Format/Done); the AI button sits to the right of Format |
| settings persistence | `lib/` via `shared_preferences` ^2.5.5 (pubspec) | the app already persists reader state locally — a settings group is natural storage |
| the content seam | `lib/services/content_store.dart` | generated content must land like any other content — an ordinary content, savable, editable, video-able |
| the segmenter | `lib/segmenter.dart` | the generated text is cut into sentences without any change to the read |
| the read | `lib/reader_service.dart` | the generated content is spoken by the unchanged read |
| the video | `lib/video_renderer.dart`, `lib/video_timeline.dart` | the generated content renders by the unchanged renderer |

## §2 Decisions

### D1 — The provider seam is a new module `lib/ai/`, not a platform channel

The provider calls are hosted REST (Gemini `generativelanguage` API, OpenRouter, NVIDIA NIM), not device capabilities.
A small `lib/ai/` module owns: the preset registry (Google AI Studio/Gemini, OpenRouter 17 `:free`, NVIDIA NIM),
the per-provider API key (SharedPreferences), the selection state, and the prompt → model call. No new platform
plugin.

### D2 — Configuration persistence is SharedPreferences (spec: "A configuration page")

`shared_preferences` ^2.5.5 is already a dependency. Presets (fixed list), per-provider API key, and selected provider
all persist as SharedPreferences keys under one namespace. Nothing in 028/027 touches this surface.

### D3 — The prompt is a single string, built in `lib/ai/` (spec FR-004)

The reader's AI prompt (their own string, spec) + optional reading content (spec A3) is composed in one pure function:
`buildPrompt(AIPrompt, String? readingContent) → String`. The provider transport is the same string across all three
presets; only the endpoint/headers differ.

### D4 — Generated content lands as an ordinary content (mirror 027's D4)

The generated text is an ordinary content in `lib/services/content_store.dart`: id, name, language, `origin: user`.
The segmenter, the read, and the renderer consume it without change. The 025 import bug fix (memory-only, no store
write) does not apply to AI-generated content — AI-generated content is *created by the reader through the app*,
so it lands like any other reader-authored content.

### D5 — No new dependency

`shared_preferences` is already in. An HTTP client: either `http` (add ^1.0) or the Dart SDK's `dart:io` HttpClient.
The plan takes `http` (cross-platform, testable); adding one dependency is justified by the plan, not by the
constitution.

### D6 — The how-to-register tips are static, per provider

Spec FR-002 ships a "how to register" tip per preset. Each tip is a plain string on the preset, i18n-able. No
dynamic link-out — the reader's own provider account stays the reader's.

## §3 Risks and reservations

- **R1** — Rate limits on the free tiers (Q5, A4/A5). The reader's prompt may be refused by the provider mid-flight;
  the error is surfaced by FR-005.
- **R2** — Provider API changes. The three presets' endpoint shapes differ (Gemini vs. OpenAI-compatible); the
  `lib/ai/` module owns the per-preset shape, so a provider change touches one file.
- **R3** — Generated content length. The content store's 100,000-character guard (008) caps the generator's output
  when it is saved; the read pipeline already enforces the same guard.

## What this research does not measure

The provider rate-limit numbers, the free-tier caps and the provider's prompt-logging behaviour are design inputs
here and become receipts at the walk (spec A5); nothing in this feature re-measures a closed feature's behaviour.
