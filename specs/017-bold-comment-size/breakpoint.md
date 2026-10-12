# 017's device walk — the record

One section per quickstart row, in the order the rows ran. Every figure below is a device run's own output on the
AVD `klhu` (`emulator-5554`, API 36, `com.example.klhu`), the debug APK built from this tree's HEAD + the working
changes of 2026-10-12. The driver is
`specs/017-bold-comment-size/scripts/klhu_walk_bold.py <row>`; screenshots and artifacts land in
`$KLHU_OUT` (default `/tmp`).

Baseline the rows are read against: `flutter analyze` clean and **647 passing** (the suite after US1's tests and
code; see `tasks.md`'s Status).

## Row 8 — the six faces, the record each bold value writes, the relaunch — WALKED, **PASS (12/12)**

```
wave 1  the control offers six chips — the presence probe is the tap the row needs anyway:
        Default ✓  Bold ✓  Serif ✓  Serif bold ✓  Mono ✓  Mono bold ✓
wave 2  each bold value through the shipped picker, then the record it wrote:
        Bold        → reading_appearance = 'bold||medium'         (two parts)
        Serif bold  → reading_appearance = 'serif-bold||medium'   (two parts)
        Mono bold   → reading_appearance = 'mono-bold||medium'    (two parts)
wave 3  the weight's own effect, family held still:
        serif||medium      6664 ink pixels
        serif-bold||medium 7622 ink pixels        (+14.4%)
wave 4  force-stop + relaunch:
        reading_appearance = 'serif-bold||medium'  (the last record held)
        the relaunched page: 7622 ink pixels        (the same paint, to the pixel)
```

**Two corrections this row made to itself, both in this pass:**

1. **The first comparison measured two things at once.** It compared the fresh `default||medium` page against
   `mono-bold||medium` and read **+12.4%** for a weight the 2026-10-12 probe put at **+39%** per glyph — because
   `mono`'s narrower glyphs fit more characters per line, so the family change moved the count the other way. The
   row now sets `Serif` and then `Serif bold` at one size and compares those (`+14.4%` above), which is the
   weight's own effect. `quickstart.md`'s row 8 carries the corrected wording.
2. **The threshold and the band.** The reading band is now `y 250..1700`: below the app bar, above the toolbar and
   the system bars, so neither an ink count nor an ink extent is decided by chrome that does not change between
   two captures. (The tighter band's counts came back **identical** to the first run's — there is no ink between
   1700 and 2050 on this page — so the band change is a safeguard, not a change in the figure.) The check needs
   **more than a tenth** more ink, a floor that a weight the probe measures at +39% per glyph clears
   unambiguously; the page's own band-level figure is +14.4%.

**What this row does and does not prove.** The weight itself (`FontWeight.w700` in the painted style, on the
reading text and the editor, never the chrome) is asserted by `test/reading_view_appearance_test.dart`'s case 17;
this row proves the shipped **picker** writes the right record, that the record survives a relaunch, and that the
paint the reader sees changes with it.

## Row 9 — `xlarge`, each bold face's widest line — WALKED, **PASS (3/3)** — 011 FR-012 re-measured

```
   default    x 353..1042   (the sans column, for reference)
   serif      x 331..1042
   mono       x 314..1042
   bold       PASS   right bound 1042, left ink drift  2 px
   serif-bold PASS   x 321..1042  (right bound 1042, left ink 331, drift 10 px)
   mono-bold  PASS   x 313..1042  (right bound 1042, left ink 314, drift  1 px)
```

**The answer to D6's open question: 011's width guarantee holds for the three bold faces.** The ink's **right**
edge is exactly the column's own right bound (1042 px) in every one of the six captures, so no line crosses the
page's right margin at the largest offered size. The **left** ink starts up to 10 px closer to the margin under a
bold weight — a bold glyph's smaller side bearing, which is a property of the weight rather than a layout change;
the row bounds that drift (12 px) and reports it rather than asserting it identical.

**Two corrections this row made to itself, both in this pass:**

1. **The first baseline compared families, not weights** — each bold face against `default`'s column — and read a
   35 px "overflow" that was Roboto's metrics against serif's. Each bold face is now compared with **its own
   family's** regular at the same size.
2. **The second assertion bound the wrong edge.** A bold glyph's ink genuinely starts a few px further left, so
   the left edge is bounded and reported while the **right** edge — what "every line inside the page" means for
   left-to-right text — is asserted. `quickstart.md`'s row 9 records the figures.

## Row 12 — a Chinese content under each bold value — WALKED, **PASS (8/8)** — the probe, confirmed on the device

```
   default    ink/area 0.047        bold        0.065
   serif               0.037        serif-bold  0.050
   mono                0.047        mono-bold   0.065

   all six paint the Chinese content (FR-005) — 12 387 and 16 087 ink pixels for the two bolds sampled
   'Mono bold' paints Chinese exactly as 'Bold' does: 0.065 against 0.065  (0.00% apart)
   'Serif bold' paints Chinese heavier than 'Serif': 0.037 → 0.050
```

**The probe's prediction, on the device and at the app's own reading size:** every family's Chinese falls back to
the same CJK face, so `mono-bold`'s Chinese is `bold`'s **to the pixel** (0.00% apart), `mono`'s equals
`default`'s, and the bold values are heavier than their regulars because the platform **synthesises** the weight —
the case the reader saw and accepted in decision 5. FR-005's glyph coverage is what the row asserts; the paint's
own look is these captures (`/tmp/017_row12_{default,serif,mono,bold,serif-bold,mono-bold}.png`).

## Row 10 — the page's measured comment size — WALKED, **PASS (4/4)**

```
   medium   the content's lines: the sentence 27 px, the comment 22 px
   small    the content's lines: the sentence 22 px, the comment 18 px
   the comment shrinks with the text: 22 px at medium -> 18 px at small   (ratio 0.82, and 10/12 is 0.83)
   the tap: the highlight (560, 597) over the comment's own line (571, 589)   (FR-010's device half)
```

**Four corrections this row made to itself, all in this pass, and the last one is the interesting one.**

1. **The first run walked a stale build.** The APK on the device was the one built during US1, so the page still
   painted the comment at the text's size — and the row *passed anyway*, on a 49 vs 33 px difference that was the
   two lines' **different letters**, not their size. Rebuilt, reinstalled, re-run.
2. **The fixture was designed for the comparison after that.** The row now seeds its own content —
   `'Hola.\n\n[注] Hola.'` — where the comment repeats its sentence's own word, so the two lines hold the same
   glyphs and their ink heights measure the **size** alone (27 vs 22 px, 22 vs 18 px). This is the same confound
   row 8's first comparison had.
3. **The band was reading the chrome.** The row's first band (49 px) was the **app bar's title**, not the
   sentence: the reading band now starts below the bar (`CONTENT_BAND`, y 430) for the rows that read lines.
4. **The ratio is the evidence, not one pair.** 18/22 = 0.82 against the derived 10/12 = 0.83 — the derived size
   the spec's decision 2 fixes, seen on the page.

## Row 11 — the comment in a frame, and 015's row 22 re-taken — WALKED, **PASS (11/11)**

```
   slot 0: frame 0  text=18  span=0..5  ink box=(208, 872, 420, 966)  height 94 px of 1080
   015's own figures for the same slot:  ink box=(208, 864, 456, 964)  height 100 px  (specs/015-comment-tag/research.md:499-500)
   the file came off the device (130 091 B), 100 of 100 frames accounted for,
   the renderer's line and the page's own message agree
```

**The block paints the same characters** (`text=18`: the sentence's 5, the line break, the comment's 12 — no tag)
and is **6 px shorter and 76 px narrower** than 015 measured, because the comment's own line is now the smaller
one. 015's row 22 and its `research.md` carry the re-taken figures with the date (T022/T023).

**One correction here too:** the first run of this row *also* walked the stale build, and its box came back
**byte-identical to 015's** — which is exactly what a row with no teeth looks like when the change under test is
not on the device. It is the reason the rebuild is in the pass's record rather than in a session note.

## Row 13 — structural: nothing installed, three labels added — **PASS (4/4)**

```
   git diff --stat pubspec.yaml pubspec.lock android/ ios/   → empty        (FR-013: no dependency, no platform file)
   lib/l10n/app_{en,es,zh,zh_Hans}.arb                       → 110 keys each (107 + fontBoldLabel,
                                                                              fontSerifBoldLabel, fontMonoBoldLabel)
   flutter gen-l10n then sha256 before/after                 → reproduces the committed Dart BYTE FOR BYTE (4 files)
   flutter test test/l10n_keys_test.dart                     → 00:00 +3: All tests passed!
```

**The one number this feature moves in another feature's records**: 016 retired a key and wrote **107**; this
feature's three labels make it **110**, and 016's own `tasks.md` carries the dated note (T028) — its breakpoint
quotes no count, so nothing there was owed (T029).

## What this walk still owes

Nothing. Every row this feature planned is walked and green: the device rows (8, 9, 10, 11, 12) and the structural
row (13). `tasks.md`'s Phase 5 carries those runs' receipts and the closing ones (T030-T032).
