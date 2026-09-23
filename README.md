# klhu — KalaHoo Reading

A read-aloud reader for language learners: tap a sentence (or the whole page)
and the app speaks it, in the right voice for the language it is written in.
Ships English, 简体中文 (with the Cantonese voices alongside) and Español.

## Features

**Reading aloud**
- Tap a sentence to hear that sentence, or `Read page` to read the page
  paragraph by paragraph with the highlight following along.
- The language is detected **per paragraph** (CJK → Simplified Chinese, Spanish
  accents/function words → Spanish, else English), so one text can mix
  languages and every paragraph still gets its own voice, in order.
- `Pause` keeps the queue and the paragraph in flight; `Resume` re-enters from
  that paragraph (paragraph-granular — there is no dependable mid-utterance
  position). `Stop` discards the queue. A read that ends by itself leaves no
  paused state behind.

**Voices**
- The voice picker lists exactly the voices the OS has installed for the active
  language, with the Chinese list carrying the Cantonese (`yue-HK`) voices: a
  dialect is a voice choice, not a second language.
- Names carry region + engine code and the gender is the only characteristic —
  and genders are **measured** (median F0 per voice, cross-checked against the
  engine's manifest), never guessed. Evidence: `specs/007-…/voice-gender-evidence.md`.
- The pick persists per language; the interface language is a separate choice.

**Editing and the content library**
- Direct edit mode (`Edit`) with the platform undo stack (`Undo` disables itself
  when the history is exhausted and says so), `Save`, `Done`.
- Saved content, written text and the shipped pre-sets live in **one list**:
  tap to load, delete behind a confirmation that warns it cannot be undone (a
  pre-set adds "…returns only if you reinstall the app").
- Titles are generated **from the content** (first non-blank line, whitespace
  collapsed, ≤ 24 characters with an ellipsis, ` (2)` on collision) — never
  translated, so a title cannot drift from the text it names.
- Saving an edited pre-set creates **new** content; the shipped original is
  never modified. Deleting a pre-set writes a tombstone: it stays gone across
  restarts and comes back if the app is reinstalled.
- Storage is one file per content plus a versioned `index.json` under the app
  documents directory (`app_flutter/content/` on Android). The list reads the
  index only — never the texts — so its latency does not grow with text size.
  Writes are `.tmp` + rename, text before index, guards before any write.
- A damaged index is moved aside as `index.corrupt-<ts>.json`, the pre-sets are
  re-seeded, and the repair is **reported** on screen instead of looking like
  data loss. An entry whose text file is gone is listed as damaged and can be
  deleted; the rest of the library keeps working.

**Interface and accessibility**
- Interface languages: English, 简体中文, Español — including the OS-visible app
  title, on a fresh install following the device locale.
- Every icon control carries a localized tooltip (which is what Android
  announces as its name), dialog buttons need no gestures, rows are ≥ 44 pt, and
  the semantics tree is asserted in tests.

## Development

```bash
export PATH=$HOME/development/flutter/bin:$PATH   # SDK lives in ~/development/flutter
flutter pub get
flutter gen-l10n                                  # after editing any lib/l10n/*.arb
flutter analyze
flutter test --concurrency=2                      # emulator up ⇒ never the default concurrency on this box
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
```

The emulator/device walk for each feature is scripted under
`~/.hermes/cache/scratch/klhu_walk*.py`; findings, per-scenario PASS/FAIL rows and
the divergences are recorded in `specs/<feature>/breakpoint.md`.

## Specs

Development is spec-driven: each feature has `specs/<NNN>-<name>/` with
`spec.md` (requirements + acceptance scenarios), `plan.md`, `research.md`
(measured facts about the device/TTS engine), `data-model.md`/`contracts/` where
it matters, `tasks.md` (one task per artifact, ticked as verified) and
`breakpoint.md` (what the device actually showed).

| Spec | What it added |
|---|---|
| 001-read-aloud | flutter_tts reading, sentence/page ranges, tap-to-read |
| 002-voice-picker | per-language voice list, picked voice persists |
| 003-reading-polish | read/edit modes, highlight, mixed-language paragraphs |
| 004-app-branding-i18n | app title/localization scaffolding |
| 005-voice-pause-resume | pause/resume + voice mapping with measured genders |
| 007-reader-name-spanish-cantonese | Spanish + Cantonese, localized reader name |
| 008-content-storage | the content library: save/list/load/edit/delete, pre-sets as data |
| 009-app-icon | launcher icon from `images/kalahoo.jpeg` (spec only) |
| 010-continue-read | set a start position and continue reading from it (spec only) |

## Known limitations

- iOS is untested (no macOS on the development host); Android is validated on
  `emulator-5554` (AVD `klhu`, API 36) and on a OnePlus 9.
- The list-open latency bar (≤ 500 ms with a seeded library) is not measured on
  device: dump-based polling costs ~2 s per sample. The structural claim — the
  list never reads text — is covered by a unit test.

## Project development based on spec-kit.

specs/001-read-aloud /002-voice-picker /003-reading-polish
Did on hermes-agent with model muse-spark-1.3-contributor-free.

specs/004-app-branding-i18n
Specs on Devin Local with model SWE-1.6 Slow. Tasks on agnes-3.0-flash, agnes-2.5-flash.

specs/005-voice-pause-resume
Specs on Devin Local with model SWE-1.6 Slow. Tasks on agnes-2.5-flash. Then Deepseek flash paid model.

specs/007-reader-name-spanish-cantonese
Specs on Devin Local with model SWE-1.6 Slow. Tasks on Deepseek flash paid.

specs/008-content-storage
Specs and tasks partly on hermes-agent (deepseek-flash); implementation, tests,
device walk and breakpoint.md on hermes-agent.
