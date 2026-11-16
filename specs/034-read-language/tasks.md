# Tasks: Read Language

**Input**: Design documents from `/specs/034-read-language/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, quickstart.md

**Tests**: INCLUDED — constitution III (test-first) requires failing tests before implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to

## Path Conventions

- Single project: `lib/`, `test/`, `specs/` at repository root

---

## Phase 1: Setup

- [X] T001 Create git branch `034-read-language` from `main`

## Phase 2: Foundational (blocking prerequisites)

- [X] T002 [P] Add `readLang` (`String`, default `'auto'`) and `roleLangs`
  (`Map<String,String>`, default const {}) to `SavedContent` in
  `lib/models/content.dart`: fields, `toJson`/`fromJson` (absent →
  defaults), `copyWith`, equality — per `specs/034-read-language/data-model.md`
- [X] T003 [P] Create `lib/read_language.dart`: `supportedReadLanguages`
  (`['en','zh-Hans','es']`), `autoLanguage`, and `resolveReadLanguage`
  implementing role override → main override → detected precedence
- [X] T004 Wire the new fields through `lib/services/content_store.dart`
  index read/write so settings persist per content id (verify an old
  `index.json` without the fields still loads)

## Phase 3: US1 — Content default read language (P1)

**Goal**: main-text language is auto-detected, shown, and overridable in the
Text type dialog; every read honors it from the next read.

**Independent test**: saved content with `readLang='es'` but paragraphs
detecting `en` → tap-read + Continue Read produce `language=='es'`
speeches; dialog shows Español selected after reopening.

- [X] T005 [US1] Unit tests in `test/read_language_test.dart`: precedence
  matrix (role > main > detected; auto fallthrough; unknown role name)
- [X] T006 [US1] Store round-trip test: `readLang`/`roleLangs` survive
  `SavedContent` json + `ContentStore` save/load; legacy record → auto
- [X] T007 [US1] Main-text paragraphs resolve via `resolveReadLanguage` —
  as built, inside `speech_resolver.dart`'s `_paragraphSpeeches`/`_turnSpeeches`
  (the live read path); `resolveParagraphSpeeches` keeps detection-only
  for its remaining callers
- [X] T008 [US1] In `_openTextType` (`lib/reading_view.dart:~2119`), add a
  "Reading language" section for non-preset contents: Auto + the three
  languages; Auto's subtitle shows `detectLanguage` of the first
  paragraph; selection persists via `copyWith(readLang:)` and store save
- [X] T009 [P] [US1] Add l10n keys (`readLanguageLabel`, auto-detected
  phrasing, etc.) to `lib/l10n/app_en.arb`, `app_zh.arb`,
  `app_zh_Hans.arb`, `app_es.arb`; run `flutter gen-l10n`
- [X] T010 [US1] Widget tests: dialog shows Auto + detected label; picking
  Español persists and reopens selected; preset content shows no section;
  tap-read/Continue Read honor `readLang` (fake reader language evidence)

## Phase 4: US2 — Per-role language override (P1)

**Goal**: each dialogue role shows its detected language in the role list
and can be pinned to a language; only that role's turns change.

**Independent test**: `roleLangs['阿明']='en'` → 阿明's turns read English,
other roles unchanged; survives restart; follows role name.

- [X] T011 [US2] Extend `test/read_language_test.dart`: role-name keying,
  unknown/renamed role falls back to main/detection
- [X] T012 [US2] Route role-turn language resolution in
  `lib/speech_resolver.dart` (~:304-327) through `resolveReadLanguage`
  with `role: turn.role` — thread the content's `roleLangs`/`readLang`
  from `ReadingView` into the resolver call path
- [X] T013 [US2] In the Text type dialog role `ListTile`s, show each
  role's effective language (auto → detected label) and offer an Auto +
  language picker persisting `roleLangs[role.name]` via `copyWith`
- [X] T014 [US2] Widget tests: role override affects only that role's
  turns; removed/re-added role keeps override by name; switching
  Standard↔Dialogue preserves overrides; Standard mode hides role picks
- [X] T015 [P] [US2] Extend l10n keys for role-language row/picker if T009
  didn't cover them; regenerate

## Phase 4: US3 — Stronger on-device detector (P2)

**Goal**: `detectLanguage` resolves via a bundled pure-Dart n-gram model
with rule-table fallback — accent-less Spanish stops reading as English.

**Independent test**: accent-less Spanish sentences ("Voy al cine.") detect
`es`; low-confidence input falls back to rules; zero network/native deps.

- [X] T016 [US3] Create detector corpus `tool/langid_corpus/{en,es,zh-Hans}.txt`
  (~300+ sentences each, Tatoeba CC-BY, attribution note) and generator
  `tool/gen_langid_profiles.dart` emitting char n-gram (1–4) log-frequency
  profiles to `assets/langid/profiles.json`
- [X] T017 [US3] Implement `lib/langid/langid.dart`: score text per
  language over the compile-time profiles (sum log-probs over n-grams),
  return `LangIdResult{language, confidence}` — pure Dart, no I/O
- [X] T018 [US3] Wire `detectLanguage` in `lib/language.dart`: model first,
  confidence threshold → rule-table fallback; signature unchanged
- [X] T019 [US3] Unit tests `test/langid_test.dart`: held-out sentences per
  language incl. accent-less Spanish/short turns; fallback path;
  profile-load failure → rules still answer
- [X] T020 [P] [US3] Profiles ship as compile-time constants in
  `lib/langid/profiles_data.dart` (as built — no asset bundle entry
  needed; `pubspec.yaml` untouched)

## Phase 5: Polish & cross-cutting

- [X] T021 Run `flutter analyze --no-pub` — clean
- [X] T022 Run `flutter test --concurrency=2` — full suite green
- [ ] T023 Device walk per `quickstart.md` — Spanish misdetection corrected
  via Text type; dialogue role override verified with `klhu speak`/voice
  evidence; accent-less Spanish auto-detects correctly; record results
  (breakpoint.md if issues)

## Dependencies

- T002/T003/T004 (foundational) block all story tasks.
- US1 and US2 share the seam and dialog — US2 builds on US1's dialog
  section; do US1 first.
- T009/T015 l10n can run parallel to other [P] tasks in their phases.

## Parallel opportunities

- T002 ∥ T003 (models vs new file); T005 ∥ T006 (unit vs store tests);
  T009 ∥ T007/T008; T011 ∥ T012/T013.

## Implementation strategy

MVP = US1 alone (content default fixes the reported bug). US2 adds role
overrides on the same seam — small incremental diff. Polish last.

## Phase 6: Amendment — dropdown UI + comment language (2026-11-16)

- [X] T024 [P] Add `commentLang` (`String`, default `'auto'`) to
  `SavedContent` (fields, json, copyWith, equality) and a `commentLang`
  param on `ContentStore.setReadLanguage`; round-trip + legacy → auto
- [X] T025 Thread `commentLang` through `resolveSpeeches` → `_withComments`
  (resolve via `resolveReadLanguage(detected: comment.language,
  main: commentLang)`), `videoSentencesFrom`, `VideoRenderer.render`, and
  all `reading_view.dart` call sites
- [X] T026 [P] l10n keys `readLanguageMainLabel`, `readLanguageCommentLabel`
  ×4 locales; `flutter gen-l10n`
- [X] T027 Replace `_languageChips` with `_languageDropdown`: 标准 shows
  Main text + Comments rows; 多人对话 shows Main text + per-role dropdowns;
  Auto item reads "Auto — Detected: {language}" inline (FR-012/013/014)
- [X] T028 `_setCommentLang` persists via `setReadLanguage(commentLang:)`
- [X] T029 Tests: resolver comment override (explicit pins all comments,
  auto keeps per-comment detection); store round-trip; widget tests updated
  for dropdown UI (open dropdown → pick → persists → reopens selected)
- [X] T030 `flutter analyze --no-pub` clean; `flutter test --concurrency=2` green
