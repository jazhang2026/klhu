# Research: Read Language (034)

## Decision 1 — Storage: fields on the content index record

- **Decision**: `SavedContent` gains `readLang` (default `'auto'`) and
  `roleLangs` (`Map<String,String>` role name → `'auto'`|lang). Persisted
  in `index.json` via `ContentStore`; absent in old records → auto.
- **Rationale**: Settings are per content entry (FR-007); the index record
  already round-trips per-content metadata and is rewritten on save —
  no new file, no migration.
- **Alternatives considered**: separate `shared_preferences` key per
  content (rejected — duplicates the index's ownership, risks drift on
  content delete); inside the `.txt` file (rejected — text files are
  content-only, would break extraction/import assumptions).

## Decision 2 — Resolution seam

- **Decision**: new `lib/read_language.dart` with
  `resolveReadLanguage(detected:, main:, role:, roleLangs:)` —
  precedence role override → main override → detection. Detection itself
  stays in `lib/language.dart` untouched.
- **Rationale**: FR-009 — one seam for a future detector; keeps
  `detectLanguage` pure and lets `resolveParagraphSpeeches` take an
  optional `languageFor` callback defaulting to `detectLanguage`, so all
  existing callers/tests are unaffected.
- **Alternatives considered**: threading settings through every speech
  call (rejected — wider diff, more drift); storing resolved language per
  paragraph (rejected — recomputes per read anyway, stale risk).

## Decision 3 — UI placement: inside the Text type dialog

- **Decision**: Add a "Reading language" section to the existing Text type
  dialog (`_openTextType`): a selector for the main language (Auto +
  English/中文/Español), and a language picker on each role `ListTile` in
  dialogue mode. Hidden for preset contents.
- **Rationale**: User decision (visible + changeable in Text type); the
  dialog already recomputes roles/voices on open — language rows ride the
  same refresh. No new screen.
- **Alternatives considered**: content-list long-press menu (rejected —
  user chose Text type); per-paragraph UI (rejected — out of scope).

## Decision 4 — "Auto" display value

- **Decision**: The dialog always shows a *concrete* effective language:
  for auto, run `detectLanguage` on a representative slice (first
  paragraph for main; first turn for a role — the same unit detection
  already uses). Label distinguishes "Auto (detected: Español)".
- **Rationale**: FR-006 — the reader must see what they'd get; detection
  on first paragraph is O(text) once per dialog open, not per read.
- **Alternatives considered**: whole-text detection for the label
  (rejected — paragraphs can differ; first-paragraph is the honest
  preview of "what auto does here" and cheap).

## Decision 5 — Detector: pure-Dart char n-gram model (US3)

- **Decision**: Primary detection becomes a bundled statistical model —
  character n-gram (1–4) log-probability profiles per language
  (`en`, `zh-Hans`, `es`), trained offline into a compact JSON asset
  (~100–500KB) and scored in pure Dart. `detectLanguage` tries the model
  first; below a confidence threshold it falls back to the existing rule
  table. CJK stays trivially correct through the model's own n-grams.
- **Rationale**: User chose option A — best accuracy-per-effort, zero
  native deps, fully unit-testable, same pattern as the repo's pure-Dart
  extractors (`docx_to_text`, `epub_decoder`).
- **Alternatives considered**: fastText `lid.176` via FFI (rejected —
  C++ native build for Android+iOS, no Flutter plugin); ONNX runtime
  (rejected — ~10–20MB native libs for a 3-language problem); `langdetect`
  package (rejected — bundles profiles for hundreds of languages, can't
  subset cleanly); expanding the rule table only (rejected — rules can't
  fix accent-less short Spanish reliably).
- **Training data**: small committed corpus per language (Tatoeba
  sentences, CC-BY — attribution noted) → `tool/` script emits
  `assets/langid/profiles.json`. Corpus lives in repo for regeneration.

## Decision 6 — Detector upgrade path

- **Decision**: `resolveReadLanguage` stays the only caller-facing seam;
  the detector upgrade (D5) lives entirely inside `detectLanguage`'s
  implementation — no storage or UI change.
- **Rationale**: US3 landed in this spec; the seam proved its worth.

## Open risks

- Role names are user-visible strings; overrides key on the name — a
  renamed role (edit) loses its override. Accepted: roles are derived from
  text, rename ≈ new role.
- `index.json` grows a map per content — trivial size.
- Preset exemption means shipped samples can't be overridden — their
  language is fixed anyway (spec Assumptions).
