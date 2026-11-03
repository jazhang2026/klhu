# Data model: AI Skills

**Feature**: `030-ai-skills-for-content-generation` | **Spec**: [spec.md](./spec.md)

## §1 `AISkill` — one prompt template

| field | meaning |
|---|---|
| id | a stable identifier; built-in skills use fixed IDs (`story`, `dialogue`, `lesson`), custom skills get a UUID |
| name | the display name shown in the skill picker; i18n-able |
| description | a one-liner explaining what the skill does; shown below the name in the picker |
| template | the prompt template string with `{{variable}}` placeholders; the dialog resolves placeholders before sending |
| defaultType | the generation type this skill targets; currently always `text` |
| isBuiltIn | `true` for shipped skills, `false` for reader-created ones |

A built-in skill's `template` is hardcoded in source; a custom skill's `template` is whatever the reader saved. Both share the same shape — there is no separate "built-in" data class.

## §2 Persistence

Skills live in `shared_preferences` under the key `klhu_ai_skills`, serialized as a JSON array of the above shape. The three built-in skills are seeded on first launch if the key is absent; subsequent launches merge seed entries with any custom entries already stored. A custom skill with the same `id` as a built-in overwrites the built-in entry (this is how "Save as skill" can replicate a built-in with a modified template).

## §3 Post-processor state

The post-processor is stateless — it takes a raw AI response string and returns a cleaned string. Nothing is stored. Its heuristic thresholds (max filler lines to scan, list of filler patterns) are compile-time constants, not persisted state.
