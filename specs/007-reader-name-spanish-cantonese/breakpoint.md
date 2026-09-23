# Breakpoint / device validation — spec 007 (US1 titles, US2 Spanish, US3 Cantonese)

**Device**: emulator-5554 (Android 16 / API 36, system locale `en-US`), app
`com.example.klhu`, debug build (`flutter build apk --debug`), Flutter 3.47.5.
**Method**: `uiautomator dump` for UI text (Flutter semantics), `adb logcat`
for which voice actually spoke (`GoogleTTSServiceImpl`), `shared_prefs` read
via `run-as` for persistence, `aapt2 dump badging` for launcher labels.
**Date**: 2026-09-23.

Scenarios 1–11 were walked on the pre-fix build; the four divergences found
(§Divergences) were then fixed, rebuilt, reinstalled and re-checked on device.
The TTS evidence below is from the pre-fix build — none of the fixes touch the
speech path.

## Scenario results

| # | Scenario | Result | Evidence |
|---|---|---|---|
| 1 | Title, English | PASS | app bar `KalaHoo Reading`; `aapt2`: `application-label:'KalaHoo Reading'`; actions Read/Read page/Stop/Edit |
| 2 | Title, Chinese | PASS | dropdown `English \| 中文 \| Español` → app bar `卡啦虎朗读`, actions `朗读/朗读全文/停止/编辑`, dropdown `中文` |
| 3 | Title, Spanish | PASS | → app bar `KalaHoo Lectura`, actions `Leer/Leer página/Detener/Editar`, dropdown `Español` |
| 4 | Spanish switching | PASS | `force-stop` + relaunch stayed Spanish; `flutter.interface_language = es` |
| 5 | Spanish read | PASS | ES sample + `Leer página` → speaking state (`Pausar`); logcat `Synthesis request for locale spa-USA and name es-US-language`, `TTS dispatch: es-us-x-esc-server` — no English fallback |
| 6 | Spanish voice preview | PASS | picker `18 voces`, rows `US SFB (Femenina)`, `Spain EEF (Masculina)`…; tap → logcat `Synthesis request for locale spa-USA and name es-us-x-sfb-network`; `flutter.voice_es = es-us-x-sfb-network\|\|es-US` |
| 7 | Spanish device locale | PASS* | per-app locale `es-MX` + cleared data → boots `KalaHoo Lectura` / `Español` / `Voz` with no manual pick. *`pm clear` also wipes the per-app locale (`get-app-locales` → `[]`), which is the only reason the first attempt came up English; re-set it and the default followed the locale |
| 8 | Cantonese under Chinese | PASS | Chinese UI, picker `27 个语音`: `广东话 YUF (男)`, `广东话 JAR (女)`, `广东话 YUD (男)` alongside `普通话 CCE (男)`, `台湾国语默认语音 (女)` |
| 9 | Cantonese selection + read | PASS | preview logcat `Synthesis request for locale yue-HKG and name yue-hk-x-jar-network`, `TTS dispatch: yue-hk-x-jar-server`; `flutter.voice_zh_Hans = yue-hk-x-jar-network\|\|yue-HK`; loading `中文示例` + reading the page spoke with the same `yue-HKG` request |
| 10 | Cantonese in English UI | PASS | English UI, `中文` segment: same `广东话 …` rows, Chinese-character names only, no `Cantonese`/`粤语` anywhere |
| 11 | Switching en↔zh↔es | PASS (latency unverified) | four switches, each ending on the right title (`KalaHoo Reading`/`卡啦虎朗读`/`KalaHoo Lectura`); no crash, no corrupted state. The spec's "<500 ms" was **not** measured: one `uiautomator dump` costs ~2.1 s, so this method cannot resolve it — the switch is a `setState` rebuild plus an async prefs write |
| 12 | Incomplete Spanish ARB | PASS (build evidence, not a device path) | see below — a healthy build cannot exhibit it on device |
| 13 | Cantonese unavailable | PASS (unit evidence) | `test/cantonese_dialect_test.dart` "Cantonese is additive" — the Chinese list degrades to Mandarin; this emulator *has* Cantonese, so the live path is unreachable here |

### Scenario 12 — measured, not assumed

Ran `flutter gen-l10n` against a **copy** of `lib/l10n` with `hintText` and
`resumeButton` deleted from `app_es.arb` (real `l10n.yaml` moved aside for the
run, restored afterwards):

- exit code 0 — the build does **not** fail;
- `--untranslated-messages-file` reports `{"es": ["hintText", "resumeButton"]}`;
- the generated `app_localizations_es.dart` emits the **English** strings
  (`String get hintText => 'Tap a sentence to read';`), so a missing key is an
  English string in a Spanish UI, never a crash and never a blank.

Two related facts worth keeping: `_AppLocalizationsDelegate.isSupported`
matches on `languageCode` **only**, so `es-MX` and `es-ES` device locales both
load the shipped Spanish set (this is what makes FR-007 hold with a single
Spanish translation), and `lookupAppLocalizations` *throws* for a locale the
app does not ship — unreachable in-app because `main.dart` always sets `locale`
explicitly to one of the three, and the dropdown offers no other.

## Divergences found on device (fixed, rebuilt, re-verified)

1. **Sample buttons were hardcoded** (`EN sample` / `中文示例` / `ES sample` in
   every interface) — a Spanish session showed English/Chinese buttons
   (SC-002). Now `sampleEn`/`sampleZh`/`sampleEs` in all four ARBs; device now
   shows `Muestra en inglés / Muestra en chino / Muestra en español` in Spanish
   and `英文示例 / 中文示例 / 西班牙语示例` in Chinese.
2. **Voice picker body was hardcoded English** (`18 voices`, `No voices
   installed for this language.`, `Could not load voices.`, `Retry`). Now
   `voicesCount` (ICU plural), `noVoices`, `voicesLoadFailed`, `retryButton`;
   device shows `18 voces` / `51 个语音`.
3. **No Español segment in the picker** (only English/中文), so with Spanish
   text the picker opened on the Spanish list with *no segment selected* and
   there was no way back to it from an English/Chinese list. Now three
   segments, labels from the ARB; device shows `English | Español | 中文`.
4. **The Spanish list was labelled in English** (`US SFB (Female)` while
   `app_es.arb` already had `Femenina`): `displayName` split the list language
   into zh/else. Now en/zh/es; device shows `US SFB (Femenina)`.

## Kept limitations / open items

- **Voice names on the Spanish list stay English-shaped** (`US SFB`,
  `Spain EEF`). `VoiceMapping` carries only `englishName`/`chineseName`;
  adding ~30 Spanish names for v1 was not proportionate. The *labels* are
  Spanish, the region words (`US`/`Spain`) are language-neutral. Documented,
  not silent.
- **Launcher label for `zh-HK`/`zh-TW`**: `aapt2 dump badging` reports
  `application-label-zh-HK:'KalaHoo Reading'` (falls back to the base) while
  `zh-CN` resolves to `卡啦虎朗读` from `values-zh`. aapt2's badging resolves
  language-only matches for some locales and not others, so this is **not**
  authoritative for Android's real resolution (a `zh-HK` device should match
  `values-zh`) — and it was not verified with a live launcher. Out of the
  spec's scope (it names `zh` and `es-MX`); flagged rather than closed.
- **`ios/Runner/*.lproj/InfoPlist.strings`** are structural only: no macOS on
  this host, so the iOS launcher title is unbuildable and unverified here.
- **Per-switch latency** (spec Scenario 11's 500 ms) unmeasured, see above.
