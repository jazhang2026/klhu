# Tasks: App Title Enhancement, Spanish Language Support, and Cantonese Dialect

**Feature**: `007-reader-name-spanish-cantonese` | **Date**: 2026-09-22
**Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md)

## Grounding corrections (made before Phase 2, device-verified)

Two claims in `plan.md`/`research.md` did not survive contact with the engine. Both
are corrected in `research.md` and drive the tasks below.

1. **`es-MX` is not a TTS locale on this engine.** The emulator's Google TTS reports
   `es-ES` (6 voices) and `es-US` (6 voices) and nothing else Spanish. `es-MX` is a
   *UI* locale only; speech uses `es-US` (US Spanish ≡ the Latin American variety the
   spec targets) and the voice list accepts any `es*` locale.
   Evidence: `specs/007-reader-name-spanish-cantonese/voice-gender-evidence.md`.
2. **Cantonese exists and the app already hides it.** The engine reports 7 `yue-HK`
   voices (`yue-HK-language`, `yue-hk-x-{jar,yuc,yud,yue,yuf}-{local,network}`), but
   `ReaderService._matchesLanguage` filters the Chinese list with
   `locale.startsWith('zh')`, which `yue-HK` never satisfies. Cantonese needs both a
   filter arm and a name row per voice, not a new engine capability.

User decisions taken at the start of this phase (settle the two open points):

- Titles are **KalaHoo Reading / 卡啦虎朗读 / KalaHoo Lectura** (`text.txt`'s "KalaHoo
  Reader" was a typo against the spec; the Spanish "Lectura" pairs with "Reading").
- Cantonese is **not** a separate picker tab or a second saved choice: the 7 `yue-HK`
  voices are **mixed into the Chinese (中文) voice list** and picking one *is* the
  Chinese voice pick, so Chinese text is then read in Cantonese.

## Path conventions

- `L10N` = `lib/l10n/`; `SVC` = `lib/services/`; `MDL` = `lib/models/`
- Generated localizations (`lib/l10n/app_localizations*.dart`) are committed: run
  `flutter gen-l10n` after touching any `.arb`.

---

## Phase 1: Titles on every surface (US1, P1) — FR-001/002/003/011, SC-001

- [x] T001 [L10N] `app_en.arb`: `appTitle` → `KalaHoo Reading`
- [x] T002 [L10N] `app_zh.arb` + `app_zh_Hans.arb`: `appTitle` → `卡啦虎朗读`
- [x] T003 [L10N] `app_es_MX.arb`: create with `@@locale: es_MX` and full key set
      (`appTitle: KalaHoo Lectura` + every key from `app_en.arb`, incl. `spanishNative`)
- [x] T004 `lib/main.dart`: `MaterialApp.title` → `KalaHoo Reading`
- [x] T005 `android/app/src/main/res/values/strings.xml` → `KalaHoo Reading`;
      new `values-zh/strings.xml` → `卡啦虎朗读`;
      new `values-es-rMX/strings.xml` → `KalaHoo Lectura`
- [x] T006 `ios/Runner/Info.plist`: `CFBundleDisplayName` → `KalaHoo Reading`;
      add `ios/Runner/{zh-Hans,es-MX}.lproj/InfoPlist.strings` (no macOS here — the
      plist edit is structural only and cannot be built/verified on this host)
- [x] T007 [P] `test/branding_test.dart`: assert the three app-bar titles render from
      the ARB (`KalaHoo Reading` / `卡啦虎朗读` / `KalaHoo Lectura`)

## Phase 2: Spanish as an interface language (US2, P1) — FR-004/005/007, SC-002/005

- [x] T008 `lib/models/language_preference.dart`: accept `es-MX` as a valid stored
      code; when nothing is stored, map the device locale (`es*` → `es-MX`,
      `zh*` → `zh`, else `en`) — pure function `resolveDefaultLanguage(Locale?)` so it
      is unit-testable without a device
- [x] T009 `SVC/localization_service.dart`: `resolveLocale('es-MX')` →
      `Locale.fromSubtags(languageCode: 'es', countryCode: 'MX')`;
      `loadLanguage()` passes `es-MX` through unchanged
- [x] T010 `lib/main.dart`: `supportedLocales` += `Locale.fromSubtags(languageCode:
      'es', countryCode: 'MX')`
- [x] T011 `lib/reading_view.dart`: third dropdown item (`l10n.spanishNative`,
      value `es-MX`)
- [x] T012 `lib/sample_texts.dart`: add `SampleTexts.es` (es-MX prose) + include it in
      `all`; `lib/reading_view.dart` sample row gains the Spanish button
- [x] T013 `lib/language.dart`: Spanish detection rule row — accented/CJK-free Spanish
      text → `'es'` (never `'en'`), i.e. `detectLanguage` can now return `en`/`es`/`zh-Hans`
- [x] T014 `lib/reader_service.dart`: route the language → locale mapping and the voice
      filter through one table instead of the `zh-Hans`-or-`en` ternary:
      `en` → `en-US`, `zh-Hans` → `zh-Hans-CN`, `es` → `es-US`; filter `es*` for `es`
- [x] T015 `lib/voice_store.dart`: `keyFor('es')` → `voice_es`
- [x] T016 [P] `test/spanish_localization_test.dart`: Spanish locale resolution,
      es-US speech locale, Spanish sample renders, dropdown lists Español, preference
      persists across a restart, device-locale default (`es_MX`, `es_ES` → es-MX; `zh` → zh)

## Phase 3: Cantonese voices inside the Chinese list (US3, P2) — FR-008/009/010, SC-003/006

- [x] T017 `lib/reader_service.dart`: the Chinese arm matches `zh*` **and** `yue*`, so
      the 7 `yue-HK` voices appear in the 中文 list
- [x] T018 `MDL/voice_mapping.dart`: 7 `yue-hk-*` rows named `广东话 <CODE>`
      (`yue-HK-language` → `广东话默认语音`), gender from measurement only; **no**
      `dialect` field on them (the name already carries the dialect, and a dialect
      characteristic would repeat the name — spec FR-010 satisfied by the name itself,
      Chinese characters in both interfaces)
- [x] T019 [P] `test/cantonese_dialect_test.dart`: the Chinese list reports both
      `cmn-*` and `yue-hk-*`; every `yue-hk-*` row resolves to a `广东话 …` display
      name (no raw system id, no `Cantonese`/`粤语` in the English label); picking a
      `yue-HK` voice persists as the Chinese pick and is the voice used when Chinese
      text is read

## Phase 4: Voice mapping for the new voices (evidence, not guesses)

- [x] T020 Sweep `es-*` + `yue-*` (+ the `en-us-x-sfg` / `en-gb-x-rjs` controls)
      with `TtsProbe`, analyze with `f0_pitch_report.py`, cross-check the manifest
      gender bit (`assets/voices-list-dsig.pb`)
- [x] T021 Write `specs/007-reader-name-spanish-cantonese/voice-gender-evidence.md`
      (per-voice F0, manifest bit, the two controls, dropped claims)
- [x] T022 [MDL/voice_mapping.dart] 12 `es-*` rows + the 7 `yue-*` rows from the
      measurement JSON (throwaway generator, not hand-edited); ambiguous voices carry
      no gender and say why in the table comment
- [x] T023 [P] `test/voice_mapping_test.dart`: every voice id the engine reports for
      the three lists resolves to a row (no raw-id fallback), the `广东话` rows carry
      no `dialect`, and the ambiguous voice has a null gender

## Phase 5: Build gates

- [x] T024 `flutter gen-l10n` + `flutter analyze` clean (no untranslated-message
      warnings for the new ARBs)
- [x] T025 `flutter test --concurrency=2` green (full suite; the emulator is up, so
      the default concurrency segfaults flutter_tester on this 16 GB box)

## Phase 6: On-device validation (quickstart.md scenarios 1–13)

- [x] T026 Build + install (`flutter build apk --debug`, `adb install -r`), then walk
      the 13 scenarios with `uiautomator dump`-derived taps; record PASS/FAIL and any
      divergence in `specs/007-reader-name-spanish-cantonese/breakpoint.md`
- [x] T027 Prove the Cantonese read through logcat (utterance locale + voice id) and
      the Spanish read likewise; a UI dump alone cannot show which voice spoke
- [x] T028 Scenario 12 (incomplete translation fallback) and 13 (Cantonese
      unavailable) are fallback paths a healthy device cannot exhibit — record them as
      unit-test evidence (`generate: false` ARB fallback / filter with no `yue` hit),
      not as device PASS rows

## Dependencies / ordering

- T003 blocks T007/T011/T016 (generated `AppLocalizations` needs the ARB).
- T017–T019 depend on T014 (language table) — one edit, one seam.
- T020–T023 can run any time after the sweep starts; the mapping rows are the only
  consumers of the measurement.
- Phase 6 needs T024/T025 green first.

## Grounding corrections (made during Phase 6, device-verified)

Three more claims in the earlier sections did not survive the emulator. They are
corrected here rather than silently diverging from the doc.

1. **The interface language code is `es`, not `es-MX`.** T008/T009/T011/T016 and
   `research.md`'s closing line say "es-MX stays the interface locale". The
   implementation ships one Spanish set keyed `es` (`app_es.arb` / `@@locale:
   es`), because `gen-l10n` keys the generated class off the ARB locale
   (`app_localizations_es.dart`) and because `_AppLocalizationsDelegate.
   isSupported` matches on **languageCode only** — so `es-MX`, `es-ES` and
   `es-419` device locales all load the same Spanish set. A `Locale('es','MX')`
   set would have *narrowed* device matching while shipping identical text. The
   platform metadata still uses `es-MX` (`values-es-rMX/strings.xml`,
   `ios/Runner/es-MX.lproj/`), which is where a region is meaningful. Speech is
   `es-US` (see correction 1 of the phase-2 notes and `voice-gender-evidence.md`).
2. **Cantonese is 11 table rows, not 7.** `T018`/`T022` say "7 `yue-hk-*` rows";
   the measured inventory is `yue-HK-language` plus five codes
   (`jar/yuc/yud/yue/yuf`) × local/network = 11 rows. The engine's *distinct*
   Cantonese voices are 7 (`yue-HK-language` resolves to `yue-hk-x-jar`), which
   is where the "7" came from.
3. **US2 needed four UI fixes the tasks never listed**, all found on
   emulator-5554 and all fixed (evidence: `breakpoint.md` §Divergences):
   hardcoded sample buttons, hardcoded picker body strings
   (`voicesCount`/`noVoices`/`voicesLoadFailed`/`retryButton` now in the ARBs),
   a missing `Español` segment in the picker, and English characteristic labels
   on the Spanish list (`Femenina`/`Masculina` now follow the list language).
   The app-bar title was already correct; the OS-visible title
   (`MaterialApp.onGenerateTitle`) was English in every language and now follows
   the interface language too.

## Verification summary (2026-09-23)

- `flutter analyze` — clean.
- `flutter test --concurrency=2` — **152 tests, all green** (28 added by this
  spec: `spanish_localization_test.dart`, `cantonese_dialect_test.dart`, plus
  additions to `voice_mapping_test.dart` and `branding_test.dart`).
- Device: 13/13 quickstart scenarios accounted for — 11 walked on
  emulator-5554 (with logcat voice proof for the Spanish and Cantonese reads),
  2 recorded as build/unit evidence because a healthy device cannot exhibit
  them. See `breakpoint.md`.
