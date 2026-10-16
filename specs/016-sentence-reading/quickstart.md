# Quickstart: Sentence-by-sentence reading

**Feature**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Date**: 2026-10-12

Validation guide. Every row names **how** it is proven: `[unit]` is a Dart test, `[device]` runs on the
emulator with the app installed, `[structural]` is a file/artifact check. No implementation code here.

**Written after [`tasks.md`](./tasks.md)** — 016's plan stage handed back `spec.md` + `plan.md`, and this file
was asked for at the review gate that followed the tasks list. The rows below are the contract
`tasks.md`'s Phase 6 walks (its T024-T030 read rows 5-11 of this file), and the unit rows mirror its
Phase 3/4 test tasks one for one. Row 14's task-side receipts live in `tasks.md`'s Status.

## Prerequisites

- Flutter SDK at `~/development/flutter` (`export PATH=$HOME/development/flutter/bin:$PATH`).
- Emulator for the `[device]` rows: AVD `klhu` (`emulator-5554`, API 36) —
  `flutter emulators --launch klhu`, wait for `adb devices` to list it.
- App package `com.example.klhu` (debug build installed).
- Desktop tests only need the checkout; the suite is **636 tests green on `409ffe1`** before this feature
  (measured 2026-10-12 with `flutter analyze` + `flutter test --concurrency=2`), which is the count row 14
  and `tasks.md`'s T001/T033 read against.

## Setup

```bash
cd /home/weihongzhang/Documents/GitHub/Projects/klhu
export PATH=$HOME/development/flutter/bin:$PATH
flutter pub get
flutter gen-l10n                            # regenerates lib/l10n/app_localizations*.dart
flutter analyze
flutter test --concurrency=2                # full suite; the emulator being up can make
                                            # plain `flutter test` segfault on this 16 GB host
```

Device rows:

```bash
flutter build apk --debug
adb -s emulator-5554 install -r build/app/outputs/flutter-apk/app-debug.apk
adb -s emulator-5554 logcat -c
adb -s emulator-5554 shell am start -n com.example.klhu/.MainActivity
adb -s emulator-5554 logcat -s flutter        # debugPrint output: the read range, the speak lines
```

Reading what the app left at the foot of the session (rows 8 and 11 read this, and its **absence** is the row):

```bash
adb -s emulator-5554 shell run-as com.example.klhu \
  cat /data/data/com.example.klhu/shared_prefs/FlutterSharedPreferences.xml | grep read_position
```

## Automated checks

| Command | What it proves |
|---|---|
| `flutter analyze` | no new lints (`reading_view.dart`, `comment.dart`, `segmenter.dart`) |
| `flutter test --concurrency=2` | every `[unit]` row below, plus the 636-test baseline as a regression gate |
| `flutter test test/comment_test.dart` | `stepEnd`: the range a step reads is the step, not the sentence (row 1) |
| `flutter test test/reading_view_step_test.dart` | the stepper, the comment half, ⏭ after a step, the clean relaunch (rows 2-4) |
| `flutter test test/reading_view_continue_test.dart test/reading_view_follow_test.dart` | 010's and 011's own cases after the record retired (rows 2-4's regression half) |
| `flutter test test/l10n_keys_test.dart` | the key removed from all four ARBs and nothing kept (row 13) |
| `git status --short lib/l10n` after `flutter gen-l10n` | the generated localizations are committed artifacts and the regeneration is reproducible (row 13) |
| `grep -rn "read_position" lib/ test/` | the record is gone from the tree but for one literal (row 12's second half) |
| `grep -rn "selectToReadMessage" lib/ test/` | the warning and its key are gone (row 13) |

## Re-run the device rows

The `[device]` rows are scripted — one command per row, each printing its evidence and ending with
`RESULT: PASS|FAIL`:

```bash
cd specs/016-sentence-reading/scripts
python3 klhu_walk_step.py 5      # the stepper: three presses, then a fourth that is silent
python3 klhu_walk_step.py 6      # the comment half: one press reads the sentence AND its comment
python3 klhu_walk_step.py 7      # ⏭ after a step reads only what the steps have not
python3 klhu_walk_step.py 8      # the clean relaunch: nothing comes back, no record is there
python3 klhu_walk_step.py 9      # a render from a step's position (012's machinery)

# the other features' own receipts, on a build of this change
cd ../011-reading-experience/scripts && python3 klhu_walk_experience.py 7
python3 klhu_walk_experience.py 8 && python3 klhu_walk_experience.py 10
python3 klhu_walk_experience.py 20
cd ../../010-continue-read/scripts && python3 klhu_walk_continue.py 13
python3 klhu_walk_continue.py 15 && python3 klhu_walk_continue.py 16
```

`ADB_SERIAL` (default `emulator-5554`) and `KLHU_REPO` (default this repo) override the defaults, as the
drivers this one imports already allow. `klhu_walk_step.py` imports
`specs/015-comment-tag/scripts/klhu_walk_comment.py` for the device mechanics, the content seeding and the
dispatch, and the new fixture sits beside it at
`specs/016-sentence-reading/scripts/klhu_step_fixture.txt`. Rows and divergences:
[breakpoint.md](./breakpoint.md).

## Validation scenarios

### 1. The range a step reads is the step, not the sentence — [unit]

Test: `test/comment_test.dart`, the new group "a step's own end (016)".
Steps: call `stepEnd(content, commentsRead, sentence)` over a sentence with no comment, a sentence that owns
the paragraph's comment (with the comments read and with them off), a sentence whose paragraph carries a
comment belonging to an **earlier** sentence, and a text with no comment at all; then call
`stepRanges(content)` — this feature's **second** helper, and the reason the rule is two functions rather than
the plan's one (plan §3.1's 2026-10-12 correction) — over a tagless text, an inline comment, and a comment at
the text's head.
Expected: the sentence's own end everywhere but the owning case, where the comments read gives the comment's
`contentEnd` — the sentence's end alone would drop the comment silently, because 015 speaks a comment only
when the read's range covers the comment's own span (`lib/speech_resolver.dart:190`).
Proves FR-005's mechanism, FR-006.

### 2. N presses read sentences 1..N, and the highlight always points at the next — [unit]

Test: `test/reading_view_step_test.dart`, the US1 group (tasks T006-T011).
Steps: pump the page on a three-sentence content with nothing highlighted and press ▶ four times, pumping
between presses; then repeat from a long-press on a paragraph; then from a tap on the second sentence.
Expected: presses 1-3 speak sentences 1, 2 and 3 in order and stop by themselves (SC-001); after each press
the highlight is the **next** sentence (FR-004) and after the third nothing is highlighted and **nothing is
shown** — no hint, no message (FR-008, SC-002); the first press from a clean page reads the first sentence
(FR-001); a tap's sentence is read exactly and no more (FR-002); a long-press's paragraph is read and the
paragraph stays highlighted (FR-003); the revealed sentence is inside the viewport (FR-012). The shipped cases
that asserted ▶'s warning (`test/reading_view_test.dart:199`, `:229`, `test/reading_view_edit_test.dart:195`)
are re-cut to this, and the two `findsNothing` cases beside them are untouched.
Proves SC-001, SC-002, FR-001, FR-002, FR-003, FR-004, FR-008, FR-012.

### 3. After a step: ⏭ reads the rest, Stop clears, Pause ends into the same advance — [unit]

Test: `test/reading_view_step_test.dart`, the US2 in-session group (tasks T013).
Steps: step twice, then ⏭; step, then Stop, then ▶; step, Pause, wait, Resume; and the same four over a
多人对话 content whose turn's sentence carries a role tag.
Expected: ⏭ reads only the sentences the steps had not read, in order, to the end (SC-003) — never the ones
already heard, and never from the first sentence; Stop clears the highlight and the position so ▶ starts at
the first sentence again (FR-009); the paused read's interrupted sentence finishes and the advance applies as
it does after a fresh step (FR-010); in 多人对话 one step is one sentence of a turn, read in that turn's role's
voice, and the next step is the text's next sentence (FR-011). ⏭'s own shipped case
(`test/reading_view_continue_test.dart:302`) is **not** re-cut: its rule still holds for ⏭.
Proves SC-003, FR-007's in-session half, FR-009, FR-010, FR-011.

### 4. A relaunch restores nothing, whoever set the position — [unit]

Test: `test/reading_view_step_test.dart`, the US2 relaunch group (tasks T014).
Steps: reach a position by stepping, capture the mocked prefs, then pump a **fresh** view with those prefs and
press ⏭; then repeat with a position a **tap** set; then check what each path wrote.
Expected: the fresh view paints no highlight and holds no position, and ⏭ reads from the first sentence
(FR-007, decision 5) — for a step's position and for a tap's alike; **no** `read_position_*` key is written by
either path, in the prefs map or anywhere else. This is the case that replaces 010's own restore group and
011's seeded follow case, both named in the plan's §4.
Proves FR-007, SC-005's retirement half.

### 5. The stepper on the device, and the fourth press — [device]

Test: `python3 specs/016-sentence-reading/scripts/klhu_walk_step.py 5`.
Steps: seed the fixture's first content — 011 row 23's own shape (a title with no full stop over a punctuated
paragraph, the case where "one sentence" and "one line" differ) — open it, and press ▶ four times, reading
`klhu read range:` and the `klhu speak` lines after each press and taking a screenshot of the page between
them; then dump the page after the fourth press.
Expected: press 1 reads the **title alone** (`klhu read range: 0..15`-style: start 0, end the title's own
end) and paints its line; press 2 reads the paragraph's first sentence, press 3 the next — one utterance per
press, and no press names two sentences (SC-001); after press 1 the highlight is on sentence 2 and on screen,
after press 2 on sentence 3 (FR-004, FR-012, SC-002).
**Corrected 2026-10-12 by the run**: **press 3 is the silent one** — the text's last sentence is read and the
highlight clears the moment that read finishes (FR-004 + FR-008), so there is no press left with nothing to
read; the page then has no highlighted rows and the dump carries **no message** (an unhighlighted page is the
whole of what there is to say), and a further press is FR-001's fresh start at the first sentence. The measured row numbers are written into
`breakpoint.md` rather than asserted from memory. The fixture's 多人对话 content is pressed the same way: in
that text type a step is one sentence of a turn, read in the turn's role's voice, and the next step is the
text's next sentence (FR-011) — the step's own range is the same range, and the resolution is 014's.
Proves SC-001, SC-002, FR-001, FR-004, FR-008, FR-011, FR-012.

### 6. The comment half: one press reads the sentence and the comment — [device]

Test: `klhu_walk_step.py 6`.
Steps: seed the fixture's commented content (a sentence whose paragraph carries a `[注]` comment, and a second
content where a comment sits **between** two sentences of one paragraph), open it and press ▶ twice, reading
the `klhu speak` lines and the page's dump each time.
Expected: one press produces the sentence's utterance **and** the comment's, the comment's carrying
`comment=1` and its own language's voice (015's rule; the step's range is the step, not the sentence) — press
1 never drops the comment, and press 2 starts at the sentence **after the comment**, not inside it or at the
comment's first character (the search key of plan §5 risk 2). The page paints no marker.
Proves FR-005, SC-004.

### 7. ⏭ after a step reads only what the steps have not — [device]

Test: `klhu_walk_step.py 7`.
Steps: press ▶ twice, then ⏭, and read the `klhu read range` line and the utterance list.
Expected: the range's start is the sentence the highlight sat on (the third), not 0, and the utterances are
sentences 3..N in order — none of the two already heard is spoken again. Proves the step's position is in
force inside the session while nothing is stored.
Proves SC-003, FR-007's in-session half.

### 8. The clean relaunch, and the record that is not there — [device]

Test: `klhu_walk_step.py 8`.
Steps: step twice, `am force-stop com.example.klhu`, relaunch, reopen the same content; then tap a sentence,
force-stop again, relaunch, and press ⏭ in both states. Also read the content's `read_position_*` record from
`shared_prefs` after each step and after each tap.
Expected: after the relaunch the page paints **no** highlight for a step's position and for a tap's alike, and
⏭ reads from the first sentence (`klhu read range: 0..<len>`) — 010 FR-005's fallback, which is now also what
a launch does; and **no `read_position_*` record exists at any point in the run**, neither written by a step
nor by a tap. This is the row 010's own rows 9/14 are replaced by (tasks T019, T030), so it is also the
amendment's device evidence.
Proves FR-007, decision 5, SC-005's retirement half.

### 9. A render from a step's position — [device]

Test: `klhu_walk_step.py 9`, then `ffprobe` on the pulled file.
Steps: step to a non-zero position, open the video's own review and render, then read the app's own
`klhu render slot=… span=… text=<n>` lines and the file's durations.
Expected: the first slot's `span=` begins at the step's own sentence start — the render starts where the step
left off, which is `lib/video_timeline.dart:128`'s path — and nothing else about the file changes for a
content with no comment. This row exists because 011's 2026-10-09 amendment left this path unwalked (spec's
Out of scope); 012 has no row of its own for it, so a failure here is a finding rather than a regression.
Proves FR-012's consequence off the page, SC-005.

### 10. 011's own receipts, re-walked — [device]

Test: `python3 specs/011-reading-experience/scripts/klhu_walk_experience.py 7`, then `8`, `10`, `20` — **one
row per run**.
Steps: run 011's four follow rows unchanged against a build of this change.
Expected: green, unchanged — the follow moves by sentence (7), an off-screen position is revealed before its
read (8), Stop leaves the page where it stopped (10), and the gesture's unit is what ▶ reads (20). Row 8's
**restore** half is the one piece 016 retires: the row's other half (a position set by a tap in the same
session is revealed first) is what still holds, and its record-based evidence line is dated in 011's own
record (tasks T020).
Proves SC-005, FR-012.

### 11. 010's own receipts, re-walked, with rows 9/14 replaced by the amendment's — [device]

Test: `python3 specs/010-continue-read/scripts/klhu_walk_continue.py 13`, then `15`, `16` — one row per run —
plus row 8 above as the amendment's own replacement for 9/14.
Steps: run 010's surviving rows against a build of this change; do not re-run 9 and 14.
Expected: green — a tap sets a position and Continue Read starts there (13), no position reads from the
beginning (15), Pause mid-paragraph resumes at the interrupted sentence (16). Rows 9 and 14 ("the position
survives a restart") are **not** re-run: 010 FR-008 is withdrawn in 010's own record with its date, and their
replacement row is this file's row 8.
Proves SC-005, FR-009's boundary with 010.

### 12. No dependency and no platform file moved — [structural]

Check: `git diff --stat pubspec.yaml pubspec.lock android/ ios/` → empty, and
`grep -rn "read_position" lib/ test/` → exactly one hit, `test/appearance_store_test.dart:81`'s literal.
Expected: this feature adds no package and touches no platform file (FR-014), and the retired record leaves no
live reference behind but the one literal a namespace test keeps on purpose.
Proves FR-014.

### 13. The warning's key is gone from all four locales — [structural]

Check: `test/l10n_keys_test.dart` plus the four ARBs' own counts and `flutter gen-l10n` +
`git status --short lib/l10n`.
Steps: count the non-`@` keys in `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_Hans.arb`, `app_es.arb`; run
`flutter gen-l10n` twice and compare the generated Dart; `grep -rn "selectToReadMessage" lib/ test/`.
Expected: **107** keys each (108 on `409ffe1` — the removed one is `selectToReadMessage`), no key in a
translation the template dropped (the test is bidirectional), the regenerated Dart identical to what is
committed, and no occurrence of the key anywhere. 015's row 16 — walked against 108 — is corrected with its
date in 015's own record (tasks T022).
Proves FR-013.

### 14. The suite and both list checkers, read against the baseline — [structural]

Check: `flutter analyze`, `flutter test --concurrency=2`, and the two checkers
(`check_tasks_format.py specs/016-sentence-reading`, `task_id_audit.py specs/016-sentence-reading`), all
quoted into `tasks.md`'s Status.
Expected: `flutter analyze` clean; the suite green with its count read against the **636** of 2026-10-12 and
the difference decomposed by file (this feature's new file and new group, minus
`test/read_position_store_test.dart`'s 11 cases and the cases re-cut in tasks T008/T017/T018) — a bare total
beside a changed suite is not a receipt; and both checkers green with their own output quoted.
Proves the regression gate every row above is read against (SC-001's baseline), and FR-014's side of row 12.

## Troubleshooting

- **A press reads two sentences.** The advance's search key is the step's **own** range end, not the sentence's:
  a comment sitting between two sentences of one paragraph makes those differ, and the next step then starts
  inside the comment (rows 1 and 6).
- **The comment is not spoken, on exactly the texts that use it.** The step's range was taken as
  `sentence.start..sentence.end`; 015 speaks a comment only when the range covers `comment.contentStart..contentEnd`
  (`lib/speech_resolver.dart:190`), and that span begins after the sentence's last character. Row 1's own case.
- **A highlight is still painted after a relaunch.** The restore path or the record write survived the
  deletion — `grep -rn "read_position" lib/` names the file (row 8 is the row that catches it).
- **The page shows a message at the text's end.** FR-008: nobody asked for one. `nothingToReadMessage` is
  reachable only through an **empty range** (`lib/reading_view.dart:1105`, `:2023`, `:2149`), never through the
  step's end, and §2.3's stale line (which the plan corrected on 2026-10-12) is the shape to check for.
- **A shipped test file will not compile after the store is deleted.** `test/video_aspect_test.dart` imports
  `ReadPositionStore` for its namespace case — that one is a compile error, not a failure, and it is named in
  the plan's §4 and tasks T018.
- **Row 9's render disagrees with the step.** A render starts where the position is, so a step that left the
  position behind its highlight (the FR-004/FR-012 pair) is the cause — the page's own `klhu read range` line
  and the render's `span=` should name the same sentence.

### 15. [device] the page away from the top: ▶ brings the sentence it reads into view (the reader's own report, 2026-10-16)

**Steps**: a content taller than the page at Extra large (this feature's own paragraph, twelve times), nothing
highlighted; swipe the reading area so the first sentence is off screen; press ▶ Read. The same steps on ⏭ Continue
Read are the row's own control.

**Expected**: each press starts at the first sentence (`klhu read range: 0..`), and the page's own **paint** shows the
highlight **while that sentence is spoken** — each press's own series of frames (011's `yellow_rows`) carries at least
one frame with yellow. On the 2026-10-16 build before the fix the control passed and ▶ read **2/3**: every frame of
the ▶ press was blank, the sentence spoken with the page where it was. On the fixed build, **3/3**.

**Evidence**: `klhu_walk_step.py 15`; frames `/tmp/klhu_out/016_row15_{continue,read}_<n>.png`; both presses' own
`klhu read range` and `klhu speak` lines.

Proves FR-012 (with 011's own rule that the sentence being read be visible).
