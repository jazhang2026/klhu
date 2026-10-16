# Breakpoint — the device walk of 022

Device `emulator-5554` (AVD `klhu`), package `com.example.klhu`, the debug build installed `2026-10-16 11:42:31` from
this tree (the first build carrying the rule). Every row below is the app's own evidence as the device reported it — the
`klhu follow:` lines verbatim, plus the dump's own labels where a row reads them.

The walk's own rows live in **011's driver** (`specs/011-reading-experience/scripts/klhu_walk_experience.py`), which
this feature extends with row **24** and one appended field; 011's own row 7 is **re-walked** rather than re-cut.

## The baseline, re-taken before anything is read off it

011's own row 7, on this tree and this build, as it stands — **PASS**, and its own figures are the ones every row below
is compared against (011's receipt for the same row quotes `viewport=209`; the tree measures `196`, so the number is
re-taken rather than inherited — `research.md` §2):

```
pre-set: 334 chars, 8 sentences; dpr=2.625; display 1080x1000 so the text is taller than the page
klhu speak: 8 utterances | klhu follow: 8 reports | 5 frames | viewport=196 logical
first/last report: p0 s0 top=3 bottom=31, p2 s2 top=134 bottom=196
paint: p1 s0 band=560..722px (origin 284 + 105..167×2.625) yellow=552..724px inside/outside=92912/0
RESULT: PASS
```

Its reports, verbatim, on the build that carries the rule:

```
klhu follow: p0 s0 visible=1 top=3   bottom=31  viewport=196 below=4
klhu follow: p0 s1 visible=1 top=37  bottom=65  viewport=196 below=3
klhu follow: p1 s0 visible=1 top=105 bottom=167 viewport=196 below=2
klhu follow: p1 s1 visible=1 top=124 bottom=186 viewport=196 below=1
klhu follow: p1 s2 visible=1 top=66  bottom=128 viewport=196 below=2
klhu follow: p2 s0 visible=1 top=168 bottom=196 viewport=196 below=1
klhu follow: p2 s1 visible=1 top=66  bottom=162 viewport=196 below=1
klhu follow: p2 s2 visible=1 top=134 bottom=196 viewport=196 below=0     ← the content's last sentence
```

**The same fixture, read for the `before`** (2026-10-16, morning, the tree before the rule): the same eight reports, with
**four of the seven non-final** sentences ending at `bottom=196` — the viewport's own last pixel, i.e. the sentence being
read was the bottom-most box on screen (`research.md` §1). Read against today's:

- **every** non-final report now carries `below >= 1` — the sentence being read always has a sentence after it on screen;
- the page's own movement is visible in the geometry (`p1 s1` `top=124` where the morning's run had it pinned at `196`);
- the content's **last** sentence is the only report with `below=0` — the reader's own exception, and it is the last
  sentence of the content, not a sentence that merely happens to be at the bottom;
- 011's own half is untouched: `visible=1` at **every** report, and each box inside the viewport.

## Row 24 — the read keeps a sentence ahead of it (022 FR-001, FR-009, SC-001)

`klhu_walk_experience.py 24`, on the same fixture and build — **PASS**:

```
pre-set: 334 chars, 8 sentences; display 1080x1000 so the text is taller than the page
klhu speak: 8 utterances | klhu follow: 8 reports | viewport=196 logical
every non-final report keeps a sentence below it: 7/7
the content's last sentence's own report: p2 s2 below=0 visible=True
RESULT: PASS
```

- What it checks: the reports and the utterances agree in order and count; **every** non-final report reads
  `below >= 1` and has its own box inside the viewport; the last report reads `below=0`. A report whose sentence was the
  bottom-most box on screen fails the row by name (`was the bottom-most box on screen (below=…, top=… bottom=…
  viewport=…)`) — the reader's own complaint, as a check.
- **A driver bug this row's first walk found, in its own file**: row 24 shrank the display (`1080x1000`) and did not put
  it back, so 016's own row 15 — walked minutes later, and written for a 1080×2400 screen — tapped the wrong coordinates
  and failed for a reason that had nothing to do with the app (`▶ Read is on the page`, with the toolbar 934 px above
  where that row's own band guard looks). Row 24 now calls `reset_viewport()` the way 011's own rows do, and 016's row 15
  was re-run after the reset: **3/3**.

## Row 25 — a text that fits the reading area moves the page by zero pixels (022 FR-005, SC-003)

`klhu_walk_experience.py 25`, on the same device — **PASS**. This is the row that closed the half T014 was first left
with, and it is 011's driver's own second new row:

```
pre-set: 334 chars, 8 sentences; display at its physical size, appearance at the app's own default
klhu follow: 8 reports | viewport=657 logical
the sentences' own boxes, as read: [(2, 18), (2, 38), (62, 78), (62, 98), (82, 118), (142, 158), (142, 178), (162, 198)]
every sentence inside the reading area at once: 8/8 visible, the last's bottom=198 of viewport=657 — nothing to scroll
the highlight's own top row, capture by capture: [472, 628, 628, 628, 680, 840, 840] (7 stills, 7 with a band) (down the page)
RESULT: PASS
```

- **The premise is measured, not assumed**: the reading area is **657** logical px tall (the physical display, the app's
  own appearance) against the tallest sentence's own `bottom=198`, so the text fits and there is nothing to scroll.
- **The paint half**: the highlight's own top row, capture by capture, only ever moves **down** the page
  (`472 → 840` device px) — the sentence being read walks down while the page's offset does not move. (A still taken
  after the read ends has **no** band at all — the page clears its highlight — which is how this row's first attempt
  failed on its own mechanics; the stills are now taken while the read plays.)
- A driver lesson this row cost, recorded because the next row will hit it: the walk's second still in the first attempt
  was taken after the read ended and read as "the highlight did not walk down the page" — that is the row's own timing,
  not the app's behaviour.

## Row 11 — the content's last sentence, and a text that fits (SC-003): **half walked at first, closed the same day**

- **The content's last sentence: PASS.** Row 24's own output above is the check — `below=0` and no move for it, which is
  the reader's own exception ("unless its the last sentence of the content").
- **A text that fits the visible area moves by zero pixels: NOT WALKED *as this section was first written*; walked
  later the same day by row 25 above (`driver key 25`, PASS, both halves: 8/8 sentences inside the area and the
  highlight walking down the page). The paragraph below is left as written, and this line is what corrects it.** The unit half is 011's own case (`short text:
  no scroll`, unchanged and green), and the device half has no row yet: it needs its own fixture (a content shorter than
  the reading area opened on this device), which 011's driver does not seed. Named here rather than implied by the
  neighbouring rows — the device half is owed, and this is where a reader of the record finds that out.

## Row 12 — the structural checks (FR-008, SC-006)

Taken on the finished tree, 2026-10-16, against this feature's own baseline (`810` passing, `57` test files, `129` keys
per ARB):

```
flutter analyze                   → No issues found! (ran in 0.8s)
flutter test --concurrency=2      → 01:14 +816: All tests passed!
message keys per ARB (four files) → 129 129 129 129        ← unchanged: this feature adds no string
flutter gen-l10n                  → re-run; the generated Dart is the tree's (no key moved)
test/*.dart                       → 57                     (unchanged)
git status --short android/ ios/  → empty
git diff --stat lib/video_pictures.dart lib/video_timeline.dart lib/video_painter.dart → empty
what moved                        → lib/reading_view.dart, test/reading_view_follow_test.dart,
                                    test/reading_view_step_test.dart (476 insertions, 66 deletions)
```

- The suite's `810 → 816` decomposes by file and reconciles: **+5** in `test/reading_view_follow_test.dart` (011's own
  five cases plus this feature's three, and US2's two), **+1** in `test/reading_view_step_test.dart` (US3's own case),
  `810 + 5 + 1 = 816`. Both per-file runs are quoted under their rows.
- **No message key moved**: the four ARBs are at `129` each, as at the baseline, and the generator reproduces the tree's
  Dart — this feature is a change to one page's scrolling, with no copy and no stored state.
- The platform halves and the video's own files are untouched, which is what `FR-008` rests on.

## The regression sweep of the neighbours (2026-10-16, after the closing)

This feature changes a **shared** method (`_revealRange` → `_scrollToRect`, the doorway 016's step and 011's follow
both go through) and appends a field to 011's own evidence line, so the neighbouring features' device rows were re-run
on the finished build (`lastUpdateTime=2026-10-16 13:25:27`, the tree with the rule in). Every row below is the app's
own verdict as the driver printed it.

```
011's rows   8 PASS · 9 PASS · 10 PASS · 17 PASS · 21 PASS
             20 FAIL · 23 FAIL
016's rows   5 PASS (13/13) · 6 PASS (6/6) · 7 PASS (2/2) · 8 PASS (6/6) · 15 PASS (3/3)
             9 FAIL (8/11) · 10 exit=2 · 11 exit=2 (not driver keys — the driver's own usage line settles it)
```

**011's row 20 — this feature's own doing, proved by a control run.** The row long-presses a point it measured with a
`base.dump()` taken **before** the read it performs, and its verdict is:

```
▶ sentence : (112, 159) (the paragraph holding it: 65..199)
HOLD the page the same line, held (selects the paragraph) @62,758
▶ paragraph: (201, 333) (the paragraph is 65..199)
FAIL: ▶ read (201, 333), not the long-pressed paragraph (65, 199)
```

The control: the **same tree with the lead disabled** (`_leadRect` returning `null`, nothing else touched), built and
installed, then the same two rows:

```
011's row 20 → RESULT: PASS      ← so the failure is this feature's
011's row 23 → RESULT: FAIL      ← so that one is not
```

That is the narrowing this feature records in 011's `FR-003` doing exactly what it says: a read **now moves the page**
in one case it did not before, and a row whose coordinates were measured before a read is entitled to be wrong. The
row's own subject is untouched (the gesture still picks what ▶ reads); what it needs is its own re-cut — re-measuring
the point **after** the read that moves the page. Owed, and named as owed in the amendment below rather than
half-fixed here.

**011's row 23 — red before this feature, too.** The control above keeps it failing, so it is not this feature's. Its
own verdict is about the app's stored position after a tap (`the record is None, not (the title's start, the text's
length) = (0, 62)`), and `grep -rn "read_position" lib/` finds **no** such pref anywhere in the tree — the row reads a
record the app does not write under that name. Untriaged by this feature; carried in the amendment as its own work.

**016's row 9 — red in a part of the tree this feature does not touch, and *not* control-tested.** Its own verdict:

```
FAIL 9: the render STARTS at the step's own sentence (the unwalked path) — slot 0's span starts at 0, the step is at 17
```

The subject is the render's own slot spans (012's path) — this feature touches neither the slots, the render, nor the
video. **Not attributed**: the same control run is what would attribute it, and it has not been made for this row.
Recorded with its own evidence so the next session does not have to re-run it to find the verdict.

**What the sweep therefore says about this feature**: 9 neighbouring device rows green, one row (011's 20) red
*because of* the narrowing and owed a re-cut in its own file, and two reds (011's 23, 016's 9) that the control run
puts outside this feature's account — one proved, one untested.

### The evening's close (2026-10-16, after the amendment)

- **011's row 20 was re-cut and walks green.** Its point is now derived **per gesture**, from a page first returned to
  its own top (`back_to_top`, two downward swipes), which is what makes "the same line, one tap, one hold" true again —
  the derivation used to happen once, before the read. On the build carrying the rule:

```
tap a line low on the page (sets the position) @62,758
▶ sentence : (112, 159) (the paragraph holding it: 65..199)
HOLD the page the same line, held (selects the paragraph) @62,758
▶ paragraph: (65, 199) (the paragraph is 65..199)     ← the held point's own paragraph
RESULT: PASS
```

- **016's row 9 was control-tested** (the same tree with `_leadRect` returning `null`, built and installed): its three
  failures are **identical** — `FAIL 9: the render STARTS at the step's own sentence (the unwalked path) — slot 0's
  span starts at 0, the step is at 17` / `… and that slot's span is the step's own sentence — span 0..15 against
  (17, 50)` / `… the text it paints is the sentence's own characters — text=15 for the sentence's 33`, `RESULT: FAIL
  (8/11)`. **So both of the sweep's non-022 reds are now proved not this feature's**, each by its own control run.
- What remains owed is theirs, not this feature's: 011's row 23 reads a record the app does not write (below), and
  016's row 9 is red inside the render's own slot spans. Both are carried in their own records, with the verdicts.

### A note on the line citations this feature moved, and what was and was not done about them

This feature adds ~85 lines to `lib/reading_view.dart` (and 169 to `test/reading_view_follow_test.dart`, 136 to
`test/reading_view_step_test.dart`), so **every line citation *below* those insertion points moved** — in this feature's
own artifacts (re-mapped and content-checked as they were written) and in the neighbouring specs' files, which quote the
same file.

What was done, in the sweep's own record: the neighbouring specs' citations were **re-based by the tree's own hunk
offsets** (52 of them, `git diff -U0 HEAD` → a per-line shift), which is the same method this project used for the ▶
fix of 2026-10-16 and which handles both ends of a range uniformly (52 lines were first changed by a per-symbol content
search and then **reverted**, because that search split range citations — `:522-536` became `:62-536` — and mis-picked
for names that occur many times; a reverted heuristic is cheaper than a silent one).

**What a re-base cannot do, measured**: it cannot repair a citation whose target *moved* rather than shifted. 014's
research file quotes "the language-level picker (today's caller, `lib/reading_view.dart:1939`)" for the
`VoicePickerScreen` call site — and that call site is at **:1700** today, i.e. *above* the cited line, which no uniform
shift can produce. So the honest state of those files is: citations that were correct at HEAD now point at the line they
should; citations that were already stale at HEAD stay stale by their own margin. **A per-spec content-verified remap is
owed** to each of them, and the method is the one this feature's own artifacts were written with: take the symbol the
prose names, find the line that defines it, correct the citation, and record the correction where it was made. This
feature's own artifacts are correct today (its `check_artifact_refs` reports no unresolved references).
