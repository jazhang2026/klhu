# Device validation: Continue Read (010)

**Feature**: `010-continue-read` | **Date**: 2026-09-24
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Format contract**: [contracts/read-position-format.md](./contracts/read-position-format.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400) |
| Build | `flutter build apk --debug` → `adb install -r` (two builds: before and after the FR-011 sentence split) |
| Source | working tree on top of `c880a24`; `flutter analyze` clean; `flutter test --concurrency=2` → **266 passing, 0 failing** (234 before this feature + 11 `read_position_store_test.dart` + 17 `reading_view_continue_test.dart` + 4 FR-011 cases in `reader_service_test.dart`) |
| Driver | `specs/010-continue-read/scripts/klhu_walk_continue.py 13\|14\|15\|16\|17` (`ADB_SERIAL`, `KLHU_REPO`, `KLHU_OUT` env; each part ends with `RESULT: PASS\|FAIL`) |
| Engine | Google TTS on the emulator; `logcat` tags `flutter` (app lines) and `GoogleTTSServiceImpl` (`Synthesis request for locale …`) |

Rows are **WALKED — PASS** (device PASS plus the line that proves it), **[unit]**
(the Dart test that carries it), **[structural]**, or **UNVERIFIED WITH REASON**.

Two things this feature can only prove on a device: the range the read actually started
from (`klhu read range: <start>..<end>`, a `debugPrint`, so a debug build only) and which
**sentence** went to the engine (`klhu speak p<i> s<j> "…"`). A UI dump can show neither:
Flutter exports the whole reading text as **one** semantics node
(`[42,388][1038,966]` on this device, all three paragraphs in its `content-desc`), so a
paragraph is addressed by position inside those bounds — the walk taps the block's last
line, which is inside paragraph 3.

## Validation results

| # | Scenario | State | Evidence |
|---|---|---|---|
| 1 | The button is Continue Read, in every shipped locale | **[unit]** | `flutter test test/reading_view_continue_test.dart` → "the toolbar offers Continue Read in every shipped locale" (en/zh/es tooltips) and "the message is localized, not the old hardcoded English"; the label literals in `reading_view_test.dart`, `reading_view_edit_test.dart`, `reading_view_pause_test.dart`, `branding_test.dart` were moved to the new key and the old zh literal `朗读全文` was a live assertion in the last two |
| 2 | No position → Continue Read reads the whole text | **[unit]** + **WALKED — PASS** | "with no position set it reads the whole text, as before"; scenario 15 on the device: `klhu read range: 0..334` with the text 334 chars after `pm clear` — the pre-010 page read |
| 3 | A tap sets the position; Continue Read starts there | **[unit]** + **WALKED — PASS** | "a tap sets the position; Continue Read starts there"; scenario 13: after tapping the last line of paragraph 3, `klhu read range: 286..334` (`286` is that sentence's offset in `assets/content/presets.json`) and `FlutterSharedPreferences.xml` holds `<string name="flutter.read_position_preset_en_sample">286\|\|334</string>` |
| 4 | A long-press sets the position at the paragraph start | **[unit]** | "a long-press sets the position at the paragraph start" |
| 5 | A tap during a read stops it, then continues from there | **[SUPERSEDED 2026-09-25]** | Was "a tap while speaking stops the read and re-anchors"; now "a touch during a read changes nothing (FR-025)" — a tap is also how a user wakes a dimmed display or stops a page fling, so it may not interrupt the reading. See 011 `quickstart.md` scenario 21 for the device receipt |
| 6 | Tracking follows the read from the position; the position outlives the end | **[unit]** | "tracking follows the read; the position outlives it" — the paragraph callback keeps firing for the paragraph being spoken after the anchored start, and the anchor is still in force when the queue ends |
| 7 | Nothing left to read from the position | **[unit]**, wording deviates — see Deviations | "an empty text explains itself instead of reading" + "the message is localized…". The literal is `Nothing left to read from here` (`nothingToReadMessage`), not the quickstart's `Nothing to read.`. **Only the empty-text case is reachable**: a tap always resolves to a real segment and a restored offset is re-resolved to a sentence start, so a start at/past the text cannot arise — scenario 7's step 2 as written is unreachable and still needs rewriting in the artifact |
| 8 | Changing the text clears the position, in memory and on disk | **[unit]** | "a committed edit clears the position and its record", "Save clears the position and its record", "emptying the text clears the position and its record", "switching content clears the position and its record"; store side: "clear removes the record; load is then absent" |
| 9 | The position survives a restart, and nothing else does | **[unit]** + **WALKED — PASS** | "a fresh view restores the stored position" (+ malformed and length-changed records read as absent); scenario 14: after `am force-stop` + relaunch the anchored sentence is painted again (**34 803** yellow pixels, the same count as the tap that set it) and Continue Read logs the same `286..334` as before the restart, matching the stored offset |
| 10 | Rapid taps leave the last position in force | **[unit]** | "rapid taps leave the last position in force"; store side: "the second of two saves wins" |
| 11 | Mixed-language content reads per paragraph from a non-zero anchor | **[unit]** | "mixed content reads per paragraph from a non-zero anchor" |
| 12 | Pausing inside a paragraph resumes at the interrupted sentence | **[unit]** | `test/reader_service_test.dart` → "pause in the second sentence resumes at it, not at the paragraph top" (+ "a three-sentence paragraph is spoken as three utterances in order", "every sentence keeps its paragraph language and picked voice", "a speech that begins mid-paragraph queues whole sentences"); the two 005 pause/resume cases in the same file still pass |
| 13 | On the device: tap a middle paragraph, Continue Read starts there | **WALKED — PASS** | Part 13: 0 → **34 803** yellow pixels across the tap (FR-006/SC-005); `klhu read range: 286..334` — non-zero start, a sentence start (`286`) inside paragraph 3, end at the text length; `shared_prefs` record `286\|\|334`; 1 engine `Synthesis request` for that one-paragraph read. Screenshots `010_13_before.png` / `010_13_after.png` |
| 14 | On the device: the position survives a restart | **WALKED — PASS** | Part 14: tap → record `286\|\|334` → `am force-stop` + relaunch → the same content, **34 803** yellow pixels (the restored sentence painted), Continue Read → `klhu read range: 286..334` = the stored offset |
| 15 | On the device: no position → unchanged previous behaviour | **WALKED — PASS** | Part 15: `pm clear` leaves **no** `read_position_*` record; Continue Read → `klhu read range: 0..334` = start 0 and end = text length; 3 utterances for 3 paragraphs (the pre-FR-011 queue), i.e. the pre-010 read |
| 16 | On the device: pause mid-paragraph, resume repeats only that sentence | **WALKED — PASS** | Part 16, after the FR-011 build: utterances before the pause `['p0 s0', 'p0 s1']`; pause tapped while `p0 s1` was in flight; after Resume `['p0 s1', 'p1 s0', 'p1 s1', 'p1 s2', 'p2 s0', 'p2 s1', 'p2 s2']` — the interrupted sentence repeated, **no** `s0` of that paragraph, then the rest in order; 7 utterances = the 7 sentences left to read, and **7** engine `Synthesis request` lines for those 7 utterances (one per sentence, I12/SC-006). The Pause/Resume coordinates came from a live dump taken while speaking (`105,2295`), not from a hardcoded guess |
| 17 | On the device: a sentence-queued read still reads acceptably | **WALKED — PASS (machine half)** + **UNVERIFIED (listening half)** | Part 17, three whole reads — EN (catalog fallback), then the ZH and ES pre-sets picked from the library: each **8 sentences / 8 utterances / 8 engine requests**, utterance order `p0 s0, p0 s1, p1 s0, p1 s1, p1 s2, p2 s0, p2 s1, p2 s2` for all three, each read ending on its text's last sentence (`Each block should highli…`, `每个段落都应该按顺序高亮并朗读。`, `Cada bloque se resalta y…`); engine locales **one per read** — `eng-USA`, `zho-CHN`, `spa-USA` — so no voice flicker within a read. The subjective half ("no clipped word, no long silence at the boundaries", D12's accepted cost) was **not** judged: this walk is automated and nobody listened to the audio |
| 18 | Structural: the old label is gone and nothing else moved | **[structural] — PASS with one caveat** | `grep -rn "Read page" lib/ test/` → the only match is `test/reading_view_continue_test.dart:188`, the assertion `expect(find.byTooltip('Read page'), findsNothing)` that keeps the old label out; no match in `lib/`. Changed source: `lib/reading_view.dart`, `lib/read_position_store.dart` (new), `lib/reader_service.dart`, `lib/l10n/*` (4 ARBs + 4 generated files). `git status --short android/ ios/` → empty: no platform work |

## Contract: the stored format ([contracts/read-position-format.md](./contracts/read-position-format.md))

| Rule | State | Evidence |
|---|---|---|
| `<offset>\|\|<charCount>` under key `read_position_<content id>` | **[unit]** + **WALKED — PASS** | `test/read_position_store_test.dart` → "the stored value is exactly `<offset>\|\|<charCount>`"; the device record above is exactly `286\|\|334` under `flutter.read_position_preset_en_sample` |
| A length mismatch or an offset past the end is discarded | **[unit]** | store tests "a length mismatch is discarded and leaves the record untouched", "an offset at or past the end of the text is discarded" |
| Every malformed value reads as absent, never throws | **[unit]** | store test "every malformed value reads as absent and never throws"; view test "a malformed stored position is ignored" |
| A position is never read for another content | **[unit]** | store tests "a position for one content is never read for another", "clearing one content leaves another content's record alone", "the namespace cannot collide with the voice or language keys" |
| Storage unavailable → the read still works, position only in memory | **UNVERIFIED WITH REASON** | The store is failure-tolerant by construction (every `shared_preferences` call is wrapped and an unavailable store degrades to "no position"), but no test or device step forces a platform-channel failure on this host; the contract's error state is therefore asserted at code level only |

## Post-review fixes (user-directed, after the rows above)

| Change | State | Evidence |
|---|---|---|
| The `Reading: <name>` caption is gone from the page | **WALKED — PASS** | Part of a two-fix review pass. `currentContentLabel` is dropped from all four ARBs (+ regenerated l10n) and the caption block from `lib/reading_view.dart`, together with the field and helper it was the only reader of (`_loadedName`, `_displayName`). On the device the page dump has **no** node starting with `Reading` — the pre-fix dump of the same page carried `Reading: El sol salió sobre el p…` |
| Read (▶) with no highlight starts at the first sentence and reads to the end | **WALKED — PASS** | The button used to set `hintText` ("Tap a sentence to read") and speak nothing. Fresh `pm clear`, no tap, tap ▶ → `klhu read range: 0..334` (first sentence to the text's end) and utterances `p0 s0, p0 s1, p1 s0, p1 s1, p1 s2, p2 s0, p2 s1, p2 s2`; `hintText` dropped from all four ARBs. Two 003-era tests were rewritten to pin the new behaviour (`Read with no tap starts at the top of the text`, `Read speaks the pending sentence; with none it reads from the top`) |
| **Superseded 2026-09-25** (011 FR-022/FR-023): ▶ with no highlight asks for a selection instead of reading | **WALKED — PASS** | See 011 `quickstart.md` scenario 20 and the row below |
| The position lives exactly as long as the highlight that shows it (011 FR-022) | **WALKED — PASS** | 011 scenario 20 on the installed build: a tap paints its line (105 968 yellow px) and stores `read_position_…112\|\|334`; after ⏭ ran from 112 to the text's end the screenshot has **0** yellow px and `FlutterSharedPreferences.xml` has **no** `read_position_*` record — a later ⏭ then reads `klhu read range: 0..334`, the read a never-tapped page gives. Stop, the end of a read and entering EDIT all clear it; the record therefore survives a restart only while its highlight is up when the app is left (row 9/14 above still hold for that case) |
| ▶ reads exactly the page's selection: the unit is picked by the page gesture (011 FR-024) | **WALKED — PASS** | 011 scenario 20, at Extra large so the page scrolls: one point on the page (`62,792`) TAPPED selects a sentence and ▶ logged `klhu read range: 112..159` — one sentence, strictly shorter than the paragraph holding it (`65..199`) — while the same point HELD (a 900 ms `input swipe` with no travel) selects the paragraph and ▶ logged `65..199`, exactly that paragraph. The button itself has one press: an earlier build gave ▶ its own tap/hold units, which is **not** what the user asked for (the unit comes from the selection, as 003 already defines it) |

Both fixes: `flutter analyze` clean, `flutter test --concurrency=2` → **266 passing, 0 failing**,
APK rebuilt and reinstalled, device rows above re-walked on the installed build.

## Deviations found while validating

1. **`T002` ran before `T001`**, the reverse of the dependency line: the baseline (234 green, analyze clean) has to exist before any file moves.
2. **The view writes persisted state, so the mocked `shared_preferences` store crosses tests inside a file.** `reading_view_test.dart` and `reading_view_edit_test.dart` called `setMockInitialValues({})` once at file scope; with the anchor persisted, a position set in one test was restored into the next (`Read with no tap prompts instead of reading page`, `Read speaks pending sentence` went red). Both files now reset the mock in `setUp`. The plan said these files change "only their label literal" — they also needed this.
3. **The listen check is not evidence.** Scenario 17's listening half needs a human; the automated half (per-sentence utterances, one locale per read, ending on the last sentence) is what is claimed here.
4. **Scenario 3's "contiguous ranges" in the artifact is wrong**: the spoken ranges cover the text with only paragraph whitespace between them (`61` vs `65` at a blank line), not contiguously. The test asserts coverage; `quickstart.md` and `data-model.md` I2 still say contiguous.
5. **Scenario 7's second step is unreachable** (see row 7) and the message wording differs from the quickstart.
6. **The walk driver is `klhu_walk_continue.py`**, not the `continue_read_walk.py` of T012 — it follows `specs/008-content-storage/scripts/klhu_walk*.py`.
7. **`pm clear` wipes a per-app locale** (`cmd locale set-app-locales`), so the device rows set the locale *after* clearing; parts 13–17 do not need it (the pre-set content is picked from the library, and the catalog fallback is the EN pre-set regardless of UI language).
