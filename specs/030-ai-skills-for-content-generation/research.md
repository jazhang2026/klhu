# Research: AI Skills for Content Generation (030)

**Feature**: `030-ai-skills-for-content-generation` | **Date**: 2026-11-03 | **Spec**: [spec.md](./spec.md)

## §1 What the tree already carries

| need | where | what it answers |
|---|---|---|
| the AI prompt dialog | `lib/reading_view.dart` (`_AIPromptDialog`, L3950+) | the UI surface where prompts are typed and submitted; skills would augment this |
| the AI provider transport | `lib/ai/provider_client.dart` | the HTTP call to the chosen provider; skills reuse this transport |
| role tag parsing | `lib/dialogue.dart` | `{name}：` prefix pattern; skills must produce this format |
| comment tag parsing | `lib/comment.dart` | `[comment]` / `[注]` / `[註]` / `[nota]` patterns; skills must produce these |
| head tag parsing | `lib/head_tag.dart` | `#` / `##` title/subtitle patterns |
| scene tag parsing | `lib/scene_tag.dart` | `[scene]` / `[场景]` patterns |
| text type switching | `lib/role_store.dart` | 标准 vs 多人对话 mode; skills should let the reader pick |
| AI config store | `lib/ai/config_store.dart` | provider list, last type, prompt history |
| the AI prompt builder | `lib/ai/prompt.dart` (`buildPrompt`) | composes the final prompt string sent to the provider |
| spec 029 infrastructure | `lib/ai/` module | all the plumbing skills ride on — no new dependency needed |

## §2 Decisions

### D1 — Skills as prompt templates, not a separate app layer

A skill is a **pre-built prompt template** stored locally (SharedPreferences, like provider config). When the reader picks a skill, the template's static text is merged with any per-run overrides (the simple request, the content type, the role list) to form the final prompt sent through the existing `AIProviderClient`. No new HTTP transport, no new server — just a different prompt.

### D2 — One `AISKill` entry per skill shape

```dart
class AISkill {
  final String id;               // e.g. "story", "dialogue", "lesson"
  final String name;             // display name (i18n)
  final String description;      // one-liner shown in the picker
  final String template;         // the prompt template with {{variables}}
  final AIPromptType defaultType; // text is the only type for now
}
```

Templates use `{{variable}}` placeholders that the dialog fills before sending.

### D3 — Where the skill picker lives

The skill picker appears **inside the AI prompt dialog**, above the prompt text field — replacing the blank-prompt experience. The reader either:
1. Picks a skill → the template fills the prompt field (editable before submit), or
2. Types a free-form prompt → no skill is used.

This keeps the existing dialog shape; skills are an opt-in enhancement.

### D4 — Output post-processing (filter header/footer)

After the AI returns text, the app runs a light post-processor:
- Strip leading/trailing conversational filler ("Sure! Here's your story...", "Let me know if you need anything else!")
- Keep only the reading-content portion, identified by looking for the first `{` or `[` tag or the first line that doesn't start with a conversational marker.

This is a heuristic, not a guarantee — the reader can still edit the result.

### D5 — No new dependency

All state lives in `shared_preferences` (already a dependency). The skill templates are hardcoded in the app source (not downloaded), so no network fetch for skills themselves.

## §3 Risks and reservations

- **R1** — Template brittleness. A poorly written template may produce content the reader has to heavily edit. Mitigation: ship a small set of well-tested templates; let the reader edit and save their own.
- **R2** — Post-processing false positives. Stripping "conversational filler" could accidentally remove legitimate content that starts with words like "Sure,". Mitigation: the strip range is narrow (first 2-3 lines only); the reader can undo.
- **R3** — Skill proliferation. Too many skills clutter the picker. Mitigation: start with 3-4 core skills; the reader can add more via a "Save current prompt as skill" action.

## §4 What this research does not measure

- Provider-specific prompt engineering (this is a spec/UX problem, not a research problem).
- The exact regex for header/footer stripping (prototype and measure on real output).
- I18n of skill names and descriptions (deferred to implementation; the shape supports it).
