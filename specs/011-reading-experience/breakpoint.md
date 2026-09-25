# Device validation: Reading Experience (011)

**Feature**: `011-reading-experience` | **Date**: 2026-09-25 (closed)
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Contract**: [contracts/appearance-format.md](./contracts/appearance-format.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400; the page-follow rows shrink the display to 1080×1000 with `wm size` and reset it afterwards) |
| Build | `flutter build apk --debug` → `adb -s emulator-5554 install -r` (the APK is rebuilt for the amendment rows; `adb install` without `-s` fails while a second device is attached) |
| Source | working tree on top of `dd09278`; `flutter analyze` clean; `flutter test --concurrency=2` → **301 passing, 0 failing** (266 at 010's close + 35 added here: sentence tracking, the follow suite, the appearance store/screen, the "`+`" suite, the FR-022–FR-025 amendment cases) |
| Driver | `specs/011-reading-experience/scripts/klhu_walk_experience.py 7\|8\|9\|10\|16\|17\|20\|21` (`ADB_SERIAL`, `KLHU_REPO`, `KLHU_OUT`; each part ends with `RESULT: PASS\|FAIL`) — imports `specs/010-continue-read/scripts/klhu_walk_continue.py` for the shared device mechanics |
| Engine | Google TTS on the emulator; `logcat` tags `flutter` (app lines: `klhu speak`, `klhu follow`, `klhu read range`) and `GoogleTTSServiceImpl` |

Rows are **WALKED — PASS** (device PASS plus the lines that prove it), **[unit]** (the Dart test that
carries it), **[structural]**, or **UNVERIFIED WITH REASON**.

Two things this feature can only prove on a device: the geometry the page decided on
(`klhu follow: p<i> s<j> visible=<0|1> top=<t> bottom=<b> viewport=<h>` — `top`/`bottom` are the
sentence's box inside the **reading area**, so they say nothing about how far the page scrolled) and
which sentence went to the engine (`klhu speak p<i> s<j> "…"`). The paint claim is a pixel claim: the
highlight is the only yellow on screen, so a screenshot gives it a row band, and the band is compared
with the band the reported box maps to (`origin + top × dpr`).

## Validation results

| # | Scenario | State | Evidence |
|---|---|---|---|
| 1 | The reader reports the sentence it speaks, with its offsets | **[unit]** | `test/reader_service_test.dart` sentence-callback cases: one report per sentence in order with its paragraph/sentence indices and absolute offsets, a mid-paragraph start reports its remainder first, and a resumed read reports the interrupted sentence again (the six old paragraph-level drives were migrated, not deleted) |
| 2 | A text that fits on screen is never scrolled | **[unit]** | `test/reading_view_follow_test.dart` → "short text: no scroll" |
| 3 | A sentence below the fold is revealed | **[unit]** | `test/reading_view_follow_test.dart` → "long text: the spoken sentence comes into view" |
| 4 | A read that starts below the fold shows that position first | **[unit]** | `test/reading_view_follow_test.dart` → "Continue Read from a stored position" |
| 5 | A manual scroll survives until the next sentence | **[unit]** | `test/reading_view_follow_test.dart` → "manual scroll is not undone" |
| 6 | Reported offsets are always inside the content, and never go backwards | **[unit]** | `test/reading_view_follow_test.dart` → "offsets are in range and monotonic per read" |
| 7 | On the device: the page follows a long read, sentence by sentence | **WALKED — PASS** | Part 7 at Extra large with the display at 1080×1000 (a 209 logical-px reading area): **8 utterances** (`klhu speak`) = **8 reports** (`klhu follow`) over 5 frames, first `p0 s0 top=3 bottom=31`, last `p2 s2 top=147 bottom=209` — every report inside the area and monotonic; the paint of `p1 s0` measured `yellow=552..724` device px against the reported band `560..722` (origin 284 + 105..167 × 2.625 dpr), inside/outside counts **92 912 / 0** |
| 8 | On the device: a stored position that is off screen is revealed first | **WALKED — PASS** | Part 8: a tap set the position at `112..334` (painted `640,816` device px); after a manual swipe **no** yellow is on screen (the position is off screen); Continue Read's first report is `p0 s0 visible=1 top=0 bottom=62` with `klhu read range: 112..334` (the tapped offset) and the highlight revealed at `yellow=284..452` — inside the reading area `284..832` |
| 9 | On the device: a text that fits on screen never moves | **WALKED — PASS** | Part 9 with the Spanish pre-set (fits): 8 reports, all `visible=1`, the text block's top **346 → 346** (never scrolled), and the per-frame yellow counts `[0, 396, 448, 552, 604, 656, 760, 816, 868, 0]` — a highlight while sentences were spoken, none before the first or after the last |
| 10 | On the device: Stop mid-read leaves the page where it stopped | **WALKED — PASS** (after a driver fix — see Deviations 1) | Part 10 at Extra large, 1080×1000: the page **moved** during the read (`top vs mid` **10.85 %** of pixels), the read stopped with the highlight cleared (`yellow=0`, `before 0`) and the page still as far from the top of the text as the read had left it (`top-of-page vs after` **10.50 %**, settled to **0.00 %** a second later) |
| 11 | The appearance control is idle-only and localized | **[unit]** | `test/reading_view_appearance_test.dart` → "the action is offered when idle, disabled while a read plays" (+ the four-locale tooltip row) |
| 12 | The offered sets are the contract's, and the largest size still fits the width | **[unit]** | `test/appearance_store_test.dart` (three typefaces, four sizes, the size constants) + `test/reading_view_appearance_test.dart` (the offered sets, and the longest shipped line at the largest size inside a 360 dp viewport with no overflow) |
| 13 | Confirming applies to the reading text and the editor, and not to the app's chrome | **[unit]** | `test/reading_view_appearance_test.dart` → "the choice styles the text, not the app" |
| 14 | Choosing, persisting and reloading an appearance | **[unit]** | `test/appearance_store_test.dart` (round-trip, one key per confirm, the second save wins) + `test/reading_view_appearance_test.dart` (a fresh view renders the stored family and size) |
| 15 | Dismissing the screen remembers nothing; malformed values fall back per field | **[unit]** | `test/reading_view_appearance_test.dart` → "dismissing writes nothing and keeps the look"; `test/appearance_store_test.dart` → per-field fallback and every malformed shape |
| 16 | On the device: a chosen look survives a restart | **WALKED — PASS** (glyph coverage: images only) | Part 16: choosing Serif + X-Large stores `serif\|\|xlarge`; after `am force-stop` + relaunch the text block is **1428** device px tall (**578** before — the larger size re-laid it) and the read text differs from Default+X-Large by **6.67 %** of pixels; the same look renders the Chinese pre-set (`klhu_walk_011_s16_serif_xlarge_zh.png`, 1087 px tall); restoring Default + Medium leaves `default\|\|medium` and a **6.69 %** difference from the serif shot. Glyph coverage for each language is what the three screenshots are for — nothing machine-readable asserts it |
| 17 | On the device: "`+`" adds a content, an empty Save adds nothing | **WALKED — PASS** | Part 17: the list opened with two entries, `Add content` opened a blank draft (the editor shows Undo/Save/Done), Save created the auto-named **`Walk note 011`** row; a second draft's empty Save showed **"There is nothing to save"** and the list gained no row (also no `read_position_*` record); leaving a third draft with Done created nothing, and a typed one (`Ticked draft 011`) did — the entry appears in the list either way |
| 18 | Structural: what moved, and what must not have | **[structural] — PASS** | Changed source: `lib/reading_view.dart`, `lib/reader_service.dart`, `lib/content_list_screen.dart`, `lib/appearance_store.dart` + `lib/appearance_screen.dart` (new), `lib/l10n/*` (4 ARBs + the regenerated files). `git status --short android/ ios/` → empty: **no platform work**. `test/` gained `reading_view_follow_test.dart`, `appearance_store_test.dart`, `reading_view_appearance_test.dart`, `reading_view_new_content_test.dart` |
| 19 | Adding a content from the list: request, save, refusal, discard | **[unit]** | `test/reading_view_new_content_test.dart` + `test/content_list_test.dart` (the typed route result: add → a new-content request, a row → its entry, back → nothing; Save names the entry; an empty Save is refused with the existing message and creates nothing; leaving a draft leaves the previous content's text and position alone) |
| 20 | On the device: no highlight means no read; the page's gesture picks the unit | **WALKED — PASS** | Part 20 at Extra large: a tap low on the page painted **105 968** yellow px and stored `read_position_…\|\|112\|\|334`; ▶ **after the tap** read `klhu read range: 112..159` (one sentence, strictly shorter than the paragraph holding it — `65..199`), ▶ **after a hold on the same point** read `65..199` (exactly that paragraph), ⏭ read `112..334` (the position to the text's end); after that read **0** yellow px and **no** `read_position_*` record; ▶ then logged no range line at all with the prompt on screen; ⏭ read `0..334` — the read a never-tapped page gives |
| 21 | On the device: a touch during a read changes nothing | **WALKED — PASS** | Part 21: with `Pause` up (a read in flight), a tap, a long press and a scroll drag on the text left the read running — "still reading after tap + hold + scroll: Pause is up" — and wrote no position ("position: still none"); after `Pause`, a tap left `Resume` on offer (the parked read did not go idle); `Stop` then returned the page to idle ("Read / Continue Read are back, Pause and Resume are gone") |

## Amendments after the first pass (2026-09-25, user-directed)

| Change | State | Evidence |
|---|---|---|
| ▶ Read with nothing highlighted asks for a selection instead of reading the page (FR-023) | **WALKED — PASS** | Row 20: no range line at all and "Select a sentence or paragraph to read" on screen; the two 003-era tests that pinned "with no selection it reads from the top" were rewritten |
| The position lives exactly as long as the highlight that shows it (FR-022) | **WALKED — PASS** | Row 20: after the ⏭ read ran to the text's end, **0** yellow px and **no** `read_position_*` record — a later ⏭ read `0..334`. Stop, the end of a read and entering EDIT clear both (unit rows in `reading_view_continue_test.dart`) |
| ▶ Read speaks the page's selection: a tapped sentence or a long-pressed paragraph (FR-024) | **WALKED — PASS** | Row 20's `112..159` (tap) vs `65..199` (hold on the same point). An earlier build gave ▶ its own tap/hold units — **not** what the user asked for, and reverted |
| A touch on the text while a read plays or is parked changes nothing (FR-025) | **WALKED — PASS** | Row 21, including the scroll drag; and the handler is arena-gated (`onTapUp`, not `onTapDown`), so a touch that becomes a scroll does not select either — that was the interruption the user was hitting. Supersedes 010 US1 scenario 5 (recorded in `specs/010-continue-read/breakpoint.md` row 5 and its quickstart) |

After the amendments: `flutter analyze` clean, `flutter test --concurrency=2` → **301 passing,
0 failing**, APK rebuilt and reinstalled, rows 20 and 21 re-walked on the installed build.

## Deviations found while validating

1. **Scenario 10's original premise did not hold, twice, and the driver was fixed both times.** The
   loop accepted the first `klhu follow` report with `top > 100` as "the page has scrolled" — but
   `top`/`bottom` are the sentence's box inside the reading area, and at Extra large on a 1080×1000
   display the opening sentences are already inside the 209-px area, so FR-003 (correctly) kept the
   page still. The row then compared two screenshots that differed only by the highlight (0.47 %) and
   decided on that noise. The second attempt required `top > viewport`, which can never hold. The
   loop now waits until the **pixels** show the page has moved (`diff_share(before, mid) > 2 %`), and
   the claim is stated as a distance from the top of the text, so a run where the page never moves
   fails loudly ("the page never moved during the read — nothing to stop on") instead of passing on
   noise.
2. **Scenario 20 raced the read it had just started.** After FR-025 a touch on the text does nothing
   while a read plays, so the hold that selects the paragraph must wait for the previous read to end;
   the driver's 2.5 s inside `press_read` is not a completion signal. The batch run FAILED on this
   ("HOLD … " then no position) and the standalone run happened to pass. The driver now calls
   `base.wait_for_idle()` before each selection after a read — the same helper 010's driver already
   had, rather than a second copy of it.
3. **`ADB_SERIAL` matters when a second device is attached.** With the OnePlus 9 connected, a bare
   `adb install` fails ("more than one device/emulator") while the walk drivers pin `emulator-5554` by
   default — the first amendment walk silently measured the **old** APK because of this (it showed the
   old behaviour: a mid-read tap stopped the read and wrote `201..334`, which is how the FR-025
   receipt got its negative control).
4. **The tasks list is ticked at close, not during the work.** `tasks.md` was generated before the
   implementation and stayed open; the amendment work (FR-022–FR-025) is recorded there as T024–T027
   with the coverage rows the checker wants.
5. **Older artifacts still describe paragraph-level tracking.** Rewritten here only where this
   feature superseded them in place (003's SPEAKING bullet, 010's scenario 5 and its row 5). Still
   naming paragraph tracking: `specs/003-reading-polish/` (plan/tasks/quickstart/data-model),
   `specs/005-voice-pause-resume/spec.md` + `breakpoint.md`, `specs/010-continue-read/data-model.md` /
   `plan.md` / `quickstart.md`. Reported, not rewritten — those files are reviewed records and
   rewriting them is the user's call.
6. **iOS is unvalidated** (no macOS on this host): the appearance's per-platform font-family names are
   asserted at unit level only.
7. **Glyph coverage and "does it sound right" are not machine-checkable.** Scenario 16 records
   screenshots for the reviewer; no device row here asserts that a typeface renders every language's
   glyphs, and no row asserts audio quality.
