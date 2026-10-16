# Research: Head tags (`#` a title, `##` a subtitle)

## Grounding corrections

Four things this pass found by reading the tree and the reviewed `spec.md` against each other. Three are places
where the spec's own wording cannot be implemented as written; the fourth is a contract step the spec's FR-004
requires and does not name. Each is *reported* here with its `file:line` and settled in the artifacts this
stage owns — the reviewed spec keeps its sentences.

| The spec says | What the system says | Verdict |
|---|---|---|
| *"**Given** the reader's Appearance size is `xlarge`, … **Then** both are at the largest offered size and the title is distinguished by weight alone — the honest ceiling"* (`spec.md:110`, the reviewed wording) | FR-006 clamps **both** marks at the largest offered size and FR-007 gave **both** the bold weight — so under the rule as first reviewed, at `xlarge` and already at `large` the two marks were the same size **and** the same weight, and the scenario's "distinguished by weight" could not hold | **resolved 2026-10-13 by the reader's own amendment**, not by this stage: their ask (*可否把加粗字体 计入 大一号，大二号…*) turned the ladder into six rungs, so the subtitle and the title now take the rungs **above** the reader's own — at `xlarge` they are the largest size at **bold** and at **black** respectively (`spec.md`'s US1 scenario 4, amended; the table below). What remains a limit is narrower and named: a body **already on the last rung** (a bold face at `xlarge`) has nothing above it, so its two marks paint identically |
| *"…and a trailing `#`-sequence (`# Title #`)"* is the reader's own text (`spec.md:245`), and SC-003 lists *"a trailing `#` sequence"* among the unmarked shapes that must be **byte-identical to today** (`spec.md:299-300`) | the two readings are (i) **the whole line** is the reader's text, and (ii) only the trailing `#` is text while the line is still a title. Under (ii) the line's size and weight change, so SC-003 fails for that very shape; under (i) it is painted and read as today | **reading (i) is implemented** — it is the only one that satisfies SC-003, and it is the direction FR-014 sets (*the reader's characters are never rewritten*). The exact predicate is D2; reading (ii) is refused there with its cost. One consequence to accept, stated rather than discovered: `# Title # more` **is** a mark (the `#` there is mid-line, and the elision covers only the marker and its one space) |
| *"Out of scope: … any mark that changes a line's height or spacing"* (`spec.md:341`) | a bigger `fontSize` **is** a taller line box: Flutter's `RichText` line height follows the tallest run on the line, and the same is true in a frame (`lib/video_painter.dart:616-626` takes the block's height from `computeLineMetrics`). A 24-point title on a 14-point page cannot keep the body's line box | **the bullet is read as "no mark adds a spacing rule"** — no paragraph spacing, no `height:` multiplier, no extra padding is introduced (FR-005's *"no other line MUST be affected"* holds), while the marked line's own box is taller because its characters are. The same fact, in the other direction, is 017's already-shipped comment (`data-model.md` of 017 § The comment's size) |
| FR-004: *"no resolution handed to the engine MUST contain a `#` that is a mark, in any read path"* (`spec.md:248-249`) | the resolution's own text **is** what the engine is handed: `ReaderService._sentencesOf` slices each speech's `text` and speaks the slice (`lib/reader_service.dart:408-435`, the slice at `:416`), and 012's audio is synthesised from the same sentence text (`lib/video_renderer.dart:237-242`). Truncating at a comment's tag (`lib/speech_resolver.dart:108`) was enough for 015 because a tag sits **after** its sentence; a mark sits **before** the words of its line, so no boundary move can drop it | **the resolution's text becomes the display's** (D1, D3): a speech's text is the characters the page paints for its span, and `ParagraphSpeech` gains the display so the two producers can map their local cuts back to content offsets. This is a change to a reviewed feature's own type, declared here and in `plan.md`'s ripple 1 — FR-011's *"the read's own units MUST be exactly 016's"* is kept by construction (the elision removes no delimiter, and the offsets are mapped, not recomputed) |

Nothing else in the spec needed correcting: the four claims it makes about today's code (015's display elides a
tag, 017's size enters the page's one style seam, the resolution is where a tag is kept from the engine, the
video paints a slot's text) were checked at the sites themselves and hold — the sites and their lines are in the
fact table below, recorded rather than corrected, because a claim that survives a check is worth the reviewer's
ability to re-run it.

## Verified environment facts

| Fact | Value | Evidence |
|---|---|---|
| The suite's baseline on the day this plan was written | analyzer clean; **663 passing, 0 failing** | `flutter analyze` → `No issues found! (ran in 1.2s)`; `flutter test --concurrency=2` → `00:57 +663: All tests passed!`, 2026-10-13 09:05 |
| The message keys, before this feature | **110** per ARB, four ARBs — this feature adds **none** | `python3 -c` count over `lib/l10n/app_*.arb` |
| The offered size ladder, and the offered faces | `small` 12 · `medium` 14 · `large` 18 · `xlarge` 24; six faces, three of them at `FontWeight.w700` — and the ladder this feature derives adds two rungs **above** them: the largest size at `w700` and at `w900` | `lib/appearance_store.dart:79-91` (the ladder), `:31-39` (the faces and `all`) |
| What the platform can paint as a weight, per family (read for this amendment, 2026-10-13) | the default family is a **variable** `Roboto` instanced at `wght` 100…900 (real light/medium/bold/black); `sans-serif-condensed` and `roboto-flex` the same; `source-sans-pro` 400/600/700; `serif` 400/700 (Latin only); `cursive` 400/700; `mono`, `serif-monospace`, `casual`, `sans-serif-smallcaps` **400 only**; the device's only CJK faces are `NotoSansCJK-Regular.ttc` and `NotoSerifCJK-Regular.ttc` | `adb -s emulator-5554 shell cat /system/etc/fonts.xml`, parsed for `<family name=…>` and its `<font weight=…>` entries |
| The marker's own characters, in the shape 015 already elides | the tag **and its separator** are what `displayOf` removes (one span per comment, `[tag.start, tagEnd)`), and the same object answers a tap's `toContent` and a highlight's `toDisplay` | `lib/comment.dart:291-349` (`CommentDisplay`), `:352-366` (`displayOf`), `:328-332` (`commentSpans`) |
| The page's span tree is cut from the **display**, at every boundary either decoration has | the highlight's two ends and 017's comment spans are the cut set today | `lib/reading_view.dart:2525-2400`; the style seam is `:2396-2410` |
| The page's reading text has exactly one style seam, and the editor goes through it | *"this method is the ONE place the reading text's style is built, and the rich text and the edit field both go through it"* | `lib/reading_view.dart:2631-2486`; the edit field at `:2576-2589` (its controller holds the content as written, `:179`, `:735`) |
| Where the resolution keeps a tag from the engine today | a paragraph's speakable text **stops at its comment's tag** (`speakableEnd`), and the language is detected on what is left | `lib/speech_resolver.dart:97-132` (the truncation at `:108`) |
| The read's own unit: one speech per paragraph, cut into sentences by the reader service and mirrored by the timeline | the slice is `paragraph.text.substring(range)`, the utterance's offsets are `paragraph.start + local` | `lib/reader_service.dart:408-435`; `lib/video_timeline.dart:76-100` |
| What the device rows can read back about a read | `klhu speak p<i> s<j> [role=…] [voice=…] "«first 24 characters of the utterance»" [comment=1]` — the text the engine was handed, truncated; a `#` in it would be visible | `lib/reader_service.dart:535-546` |
| What a frame's own line reports about its block | `… span=<content start>..<end> text=<painted characters>` — the **length of the painted text**, which is how 015's row 22 proves no tag is painted | `lib/video_renderer.dart:379-389`; `specs/015-comment-tag/quickstart.md:442-446` |
| The frame's derived-size seam (017's) | the comment's size is the reading size's own derived value carried onto the frame's scale: `frameStyle.fontSize × commentPointsFor(reading) / reading` | `lib/video_painter.dart:641-646` |
| A slot's block is laid out per frame, from `slot.text`, split at one boundary index | `_blockFor` builds one or two spans and takes the lines, the height and the scroll steps from that one call | `lib/video_painter.dart:578-640` (the split at `:591-608`, `paintedText: slot.text` at `:626`) |
| The reader's own content carries **no** `#` | seven lines, `Basic Spanish 1` first, each line's comment tag with no delimiter before it | `test/step_ranges_test.dart:16-27` (copied off their phone on 2026-10-12) |
| A synthesised bold exists for CJK where no bold face ships — measured, not assumed | ink/area 0.245 → 0.369 (+51%) at 30 pt, the same across families | `specs/017-bold-comment-size/research.md:33-35` (the 2026-10-12 probe) |
| The walk device | AVD `klhu` = `emulator-5554`, API 36, package `com.example.klhu`; the drivers need `/usr/bin/python3` (3.12, PIL) | `adb devices`; `specs/017-bold-comment-size/quickstart.md:16-19` |

## The ladder (the derivation, after the reader's amendment of 2026-10-13)

```text
rung | size   | weight | how the app reaches it
0    | 12 pt  | w400   | offered: small, in the reader's own face
1    | 14 pt  | w400   | offered: medium
2    | 18 pt  | w400   | offered: large
3    | 24 pt  | w400   | offered: xlarge
4    | 24 pt  | w700   | derived: the largest offered size, bold (017's weight)
5    | 24 pt  | w900   | derived: the largest offered size, black (no control offers it)
```

The reader's own rung is the last rung not above their own choice; the title takes the second rung above it and
the subtitle the first, each clamped at the last — which is what makes the two marks distinguishable at **every**
reader size but the last rung (a bold face at `xlarge`, where both marks are the black rung). The same ladder
read **downwards** is FR-015's comment: the weight first, then the size.

## D1. The marker is *elided* — one display, a second kind of never-painted character

- **Decision**: 015's display (`lib/comment.dart`, `CommentDisplay`/`displayOf`) learns the **second** kind of
  never-painted character: alongside every comment tag's `[tag.start, tagEnd)` it removes every mark's
  `[start, markEnd)` (the `#`s **and the one space that belongs to the mark**, FR-003). One elision, one
  mapping: `toContent`/`toDisplay` iterate the two kinds' spans merged in text order. Both paints read the same
  object — the page's `_buildSpans()` (FR-003) and the frame's block, whose text comes from the *speech*, which
  is now the display's own characters (D3, so `specs/015-comment-tag/quickstart.md:442-446`'s `text=` receipt
  keeps meaning exactly what it means today: *the painted characters*).
- **Rationale**: the spec's own Assumption says this is where a never-painted character lives (`spec.md:331-332`),
  and FR-003 points at `displayOf` by name. The alternative — a second elider beside the first — is the *second
  pipeline* that assumption refuses, and it would give the page two index spaces to keep in step.
- **Alternatives considered**: **substituting the marker with spaces** instead of removing it (cheaper than
  D3 by a whole field: every offset survives untouched, because `# ` and `  ` are the same length). Refused on
  two measured consequences: a frame paints its own `slot.text` (`lib/video_painter.dart:626`), so the marker's
  two spaces would be painted as an **indent** on the title's line exactly where the page paints none — the two
  surfaces would disagree about what the reader's title looks like — and the `text=` receipt 015's row 22 reads
  as *no marker is painted* would count the marker's characters as painted. Substituting with a zero-width
  space (U+200B) is the same shape with an invisible character in the text handed to the engine: refused as an
  unverifiable trick on the one path where the reader's own ear is the judge.

## D2. The recognition rule, exactly

- **Decision**: a mark is recognised at a **line's first character** and nowhere else. On the line, in order:
  the first character is `#`; the run of `#` at that position is **exactly one or two** (a third `#` is the
  reader's text, FR-002); the character after the run is **exactly one ASCII space** (U+0020 — `#\tTitle` is
  not a mark); the character after that space exists and is **not** a space or tab (so `# ` alone, `## ` alone
  and a marker followed by whitespace are the reader's text, FR-002); and the line's **last non-space character
  is not `#`** (the trailing-`#` refusal of the grounding correction above). A line inside a comment's span is
  never a mark (FR-009). Level 1 (`#`) is a title, level 2 (`##`) a subtitle.
- **Rationale**: every clause is a reader's-prose guard, and each erases in the safe direction — a shape that
  fails any clause is painted **and read** as written, never silently restyled, never repaired (FR-014). The
  four clauses are exactly the shapes SC-003 names: `#hashtag` (no space), `#1 best` (no space), `### ` (three),
  a lone `#`, a marker followed by whitespace, a marker preceded by whitespace, a trailing `#` sequence.
- **Alternatives considered**: **reading (ii) of the trailing `#`** — the line is a title and the trailing
  sequence is its own text — refused: SC-003 names that shape among those that must be *byte-identical to
  today*, and this reading changes its size and weight. **Refusing any line that carries a second `#`
  anywhere** — refused as broader than FR-002's clause and than the spec's own decisions list (*"trailing-`#`
  closers"*, `spec.md:357`), which speaks of the trailing sequence only. **Tolerating leading whitespace**
  (`  # Title`) — refused by the spec's own edge case (`spec.md:235-236`): a wrapped body line would become a
  title. **Matching the marker in the editor or on paste** — out of scope (`spec.md:346`): the rule is derived
  where it is *read*, and the reader's stored text is never rewritten.

## D3. The read's own text is the display's, and the resolution carries the mapping

- **Decision**: `ParagraphSpeech` gains a nullable `display` — the content's own display when the text it
  carries is a slice of it — and one helper on the speech turns one of that speech's **local** sentence ranges
  into the three things the two producers need: the words to hand the engine (the display's slice, so no marker
  and no tag), and the span those words occupy in the **content's** offsets. `ReaderService._sentencesOf`
  (`lib/reader_service.dart:408-435`) and `VideoTimeline.videoSentencesOf` (`lib/video_timeline.dart:76-100`)
  both call it; the two are the same algorithm today and stay so. The resolver sets it on every speech it
  builds — the standard path, 014's turns and 015's comments — and leaves it **null** when the content holds
  nothing elided, which keeps every offset, every string and every existing test of a text without a tag or a
  mark **byte-for-byte** what they were (SC-003's own shape).
- **Rationale**: FR-004 is about *the resolution*, and the resolution's `text` is what the engine is handed —
  so the marker has to leave **there**, and the one thing that must not move is the read's own units (FR-011:
  the same steps, in the same order, on the same offsets). What the marker's removal does **not** touch: it is
  not a delimiter (`lib/segmenter.dart:18`, `:41-73`), so no sentence range changes; a comment's tag is elided
  outside every sentence's span anyway (015's truncation), so a text with comments and no mark produces the
  same strings as today.
- **Alternatives considered**: **substituting spaces in the speech's text** (D1's refused alternative) —
  cheapest, but the frame paints the speech's text, so the frame would carry the marker's whitespace as an
  indent. **Passing the display to the two producers as an argument** (a `speakParagraphs(speeches, display:)`
  parameter) — refused: a caller that forgets it would hand the engine a marker silently, on the one path where
  nothing else can notice, while a field the resolver sets cannot be forgotten. **Threading the mapping through
  `SpokenSentence`** instead — refused: the page's highlight is expressed in content offsets today
  (`lib/reading_view.dart:1120` sets it from `spoken.start`/`spoken.end`) and 011's tracking, 010's resume point
  and 012's slot offsets are all in that space; moving them into display offsets would be a change to three
  features' contracts for this one's convenience.

## D4. One ladder, one helper, both paints

- **Decision**: a single helper on the reading appearance returns a mark's **rung** — the reader's own rung plus
  two (a title) or one (a subtitle), clamped at the ladder's last rung — and the rung carries **both** the size and
  the weight (the table above). Both paints call it: the page's `_spanPaint` and the frame's block, which carries
  the rung onto the frame's own scale exactly as 017's comment size does (`lib/video_painter.dart:641-646`). The
  same helper, read **downwards**, is FR-015's comment: the rung one step down, the weight first. Nothing is
  stored, and no control offers a rung.
- **Rationale**: 017's D2 with a second dimension — one site computing "two rungs up" keeps a page and a frame from
  disagreeing, and the reader asked for a relationship (*"把加粗字体计入大一号，大二号"*), not a setting. The ladder
  being one ordered list is also what makes the ladder's own limits mechanical: the clamp is the last rung, and
  the only pair that can be equal is a body already on it (SC-006).
- **Alternatives considered**: a **floor** at the reader's own weight (every mark also bold) — refused: it eats the
  ladder's bold rung, so at `large` the title and the subtitle both land on it and tie, which is the very tie the
  amendment exists to remove (the reader's own option 1 over their option 2/3); the **interleaved** ladder (a rung
  per size × weight, so "one step up" can be the same size, bolder) — refused by the reader (*"有的档很微妙"*): it
  turns a title into "the body, bolder"; **fixed** sizes (a 24-point title over a 12-point body) — refused by the
  spec's decision 3: the page would stop being the reader's own size; a **ratio** (×1.5) — refused for the same
  reason 017 refused it for the comment; a **fifth offered size** or a heading-specific face — refused by the
  spec's Out of scope and decision 6 (`spec.md:374-375`); **two helpers** (one for marks, one for the comment) —
  refused: they are the same list read in opposite directions, and two implementations of one ladder is how a
  comment and a mark come to disagree about where the next rung is.

## D5. The frame's blocks carry the mark's spans, and `buildVideoPlan` is handed the display

- **Decision**: `VideoSlot` gains the **heading spans inside its own `text`** — each `(start, end, level)` in
  that text's index space — and `buildVideoPlan` takes the content's **display** in place of the bare
  `comments` list it takes today (`lib/video_renderer.dart:268-275`, `lib/video_timeline.dart:278-283`): the
  display already carries the comments *and* the elision, so one object answers both questions. The painter's
  `_blockFor` splits the block at the heading spans as well as at 017's `commentStart`
  (`lib/video_painter.dart:591-608`), and the **comment's own characters win** where a marked line carries a
  comment: those characters keep 017's size and the face's weight (FR-012), while the rest of the line gets the
  derived size and `w700`.
- **Rationale**: 017's D4 established the shape — the painter cannot recover a boundary from content offsets
  plus a painted string, and the information exists where the block is assembled — and a *list* rather than one
  index is what a frame needs whenever its own sentence holds several marked lines (one paragraph with no
  delimiter is one sentence, hence one slot, hence one block: `# Title` + body + `## Sub` is exactly that
  shape).
- **Alternatives considered**: one `headingStart` index like 017's comment boundary — refused: the second
  marked line has nowhere to go, and the mixed slot above is not an exotic shape but the reader's own title
  over their own paragraph. Re-deriving the spans in the painter from the block's text — refused: the same
  argument as 017's D4 (searching a painted string for a `#` fails on the shapes the rule refuses, and would
  paint a marker the rule deliberately kept as text). Making the *page* pass its spans to the renderer —
  refused: the render is built from the content and the read (`videoSentencesFrom`), not from the page.

## D6. A mark's own line is the unit, and its end is the line's end

- **Decision**: the painted span of `#`/`##` is the **line the marker starts** — from the first character after
  the marker and its one space to the line's own end (the `\n` or, for the paragraph's last line, its last
  character) — and never the paragraph, never the rest of the text (FR-005, FR-008). The mark's elided span is
  the `#`-run plus the one space; neither span ever crosses a blank line, and both are derived from the
  content's own offsets.
- **Rationale**: the reader's own answer, quoted in the spec (`spec.md:27-31`): a title is a *line*, and the
  line is what their content already carries (*"The title of the content: Basic Spanish 1."*,
  `spec.md:35-37`). It is also what keeps `# Title` followed by body text **without** a blank line painting as a
  title plus body rather than swallowing the paragraph (the spec's decision 2).
- **Alternatives considered**: paragraph scope (the marker restyles everything up to the blank line) — refused
  by decision 2; document scope — refused: one `#` would restyle the whole content; the *sentence's* scope —
  refused: a line without a delimiter is not a sentence boundary, and the spec's edge case draws the line
  exactly there (`spec.md:225-226`).

## D7. The rule lives in its own module, and the display keeps its name

- **Decision**: the recognition rule is a new `lib/head_tag.dart` — `HeadTag` (level, the marker's own span,
  the line's span) and `headTagsOf(content)` — derived from the text on every read like 014's and 015's rules,
  and the only caller of it is 015's display (which needs it to know what to elide). The display's type keeps
  its name: `CommentDisplay` becomes the content's display with a second kind of elided character, documented
  in place with this feature's date.
- **Rationale**: one rule per kind of marker is what 014 and 015 already do on purpose (*"the two tags keep
  their own implementations and never call each other"*, `lib/comment.dart:6-9`), and a mark is a third kind —
  it must be recognisable without a comment in sight (a content with a title and no tag). The name is kept
  because renaming it is **counted**: 13 references in `lib/` (`lib/comment.dart`, `lib/reading_view.dart`),
  12 in `test/` (`test/comment_test.dart`, `test/reading_view_comment_test.dart`) and 9 in `specs/` —
  015's reviewed `data-model.md`/`tasks.md` and 017's `tasks.md` among them, whose sentences would then name a
  symbol that no longer exists. The spec's own Assumption approves the extension in as many words
  (`spec.md:331-332`).
- **Alternatives considered**: renaming the type to something neutral (`ContentDisplay`) and moving it to
  `lib/display.dart` — refused for the churn above, and because a *renamed* type in another feature's reviewed
  record reads as a correction that feature never asked for; putting the mark's rule inside `comment.dart` —
  refused: the rule has to answer for a content with no tag at all, and 014/015's separation is the precedent
  the reader's own decisions established.

## D8. Nothing is stored, configured or translated — and the editor is untouched

- **Decision**: no new `shared_preferences` key, no new field in any record, no new ARB key in any of the four
  locales (110 → **110**), no new dependency, no platform code. The editor keeps painting the reader's text as
  written (`lib/reading_view.dart:2661-2589`) and the stored text is byte-for-byte what the reader typed
  (FR-010).
- **Rationale**: the spec's Key Entities is *"None"* (`spec.md:286-287`) and FR-010 says the same; the marker is
  a rule for the text the reader already writes, inside two seams the app already owns (015's display, the
  resolution).
- **Alternatives considered**: remembering "this content's marks were read" (a per-content setting) — refused:
  nothing about a mark is a reader's preference, and 015's own switch exists because the *item* asked for it;
  a new label for a heading's name in the four locales — refused: the mark is the reader's own typing, not a
  string the app shows.

## D9. The ceiling is where the ladder ends — and it moved up

- **Decision**: the marks' rungs are the ladder's, so the ceiling is a body **already on the last rung** (a bold
  face at `xlarge`): there is nothing above it for the title, the subtitle takes the last rung and the title is
  clamped to it, and the case is named (SC-006), pictured by a device row, and left to the reader's own remedy (a
  smaller size, or a regular face). Every other reader size separates the three levels — at `small` and `medium` by
  size, at `large` and at a regular `xlarge` by the size and then the weight (the table).
- **Rationale**: it is the reader's own answer of 2026-10-13 — *字号优先，字重只补顶部* — taken over the two shapes
  they were shown and refused: the interleaved order (a same-size, bolder step: *"有的档很微妙"*) and a mark taken
  from a rung **below** their own (a subtitle lighter or smaller than the body, which SC-002's floor forbids). The
  amendment is theirs, and this decision records what it bought and what it could not.
- **The honest limit that survives**: **for CJK — and for `mono`, `serif-monospace`, `casual` and
  `sans-serif-smallcaps` — a weight rung is the platform's synthesised weight, where a size rung is a real one**
  (the device's own font table, above; 017 measured the synthesis at +51% ink for Chinese at 30 pt,
  `specs/017-bold-comment-size/research.md:33-35`). A Chinese reader's title is therefore heavier by the platform's
  faking, and a Chinese subtitle at `large`/`xlarge` differs from the body by that faking alone — the walk pictures
  both rather than asserting either.
- **Alternatives considered**: leaving FR-006/FR-007 as first reviewed and shipping two identical marks at
  `large`/`xlarge` — refused by the reader's own ask (counting bold into the steps is exactly what they asked for);
  choosing for them between the three shapes — refused: this is what a page shows, and their rule for that is to be
  given the options with their costs (they were, and they answered).

## Open questions (implement time answers these; each has its fallback chosen)

1. **Does the elision of the marker move any *painted* boundary the reader would notice?** The marker sits at a
   line's start, so its removal shifts that line — and every later line of the same paragraph — left by its two
   characters. The page's mapping answers every *offset* (tap, highlight, step) exactly (D1's invariants), and
   the alternative is not available: painting the two characters as spaces is what the frame would then paint.
   The walk's screenshots decide whether the shift reads as "the marker is gone" or as "the paragraph is
   indented" (a title line that had a marker now starts at the left margin, like every other line).
   **Fallback if it reads oddly**: the elided span is the `#`-run alone (one or two characters) plus a
   *collapsed* space — a change to FR-003's own wording (*"the `#`/`##` and the space after it"*,
   `spec.md:246-247`), taken with the reader.
2. **The weight rungs' own look, per script and per family.** The black rung is a **real** face for the default
   family (Roboto's `wght` axis reaches 900 on this device) and a **synthesised** one for CJK, `mono`,
   `serif-monospace`, `casual` and `sans-serif-smallcaps` (the font table above); 017 measured the synthesis at +51%
   ink for Chinese against the shipped real bold's +47% for Latin. Whether a Chinese title at the black rung reads
   as heavier than a bold subtitle — or as the same weight twice — is a picture, not an assertion, and the rows that
   take it are `quickstart.md` 5 (the page) and 12 (the frame).
   **Fallback if it does not read**: the ladder's last rung is dropped for the scripts and families without a real
   face (the title then clamps to the bold rung and the exhausted-top case widens by one rung) — a change to D4,
   priced as one row plus the ladder's table.
3. **A marked line inside a frame that scrolls.** A title line is a *tall* line, and 012's block scrolls a line
   at a time when its text does not fit (`lib/video_painter.dart:570`, `:630-640`). The scroll steps are taken
   from the same one layout call, so the arithmetic follows from the new sizes; the row that measures it is
   `quickstart.md` 12 (a title over a long body in one slot).
   **Fallback if the block overflows the frame's column**: the row records the measured steps and the reader is
   offered a smaller top size for a title in a frame — a change to D4, priced as one.
4. **A bold body's marks are bigger and lighter** (the amendment's own consequence: a rung carries one weight, and
   the rungs above a bold body at `small`/`medium`/`large` are regular). Whether that reads as a title — or as the
   reader's bold paragraph with a lighter heading above it — is the walk's picture (`quickstart.md` 5b).
   **Fallback if it reads as a demotion**: the weight floor D4 refuses comes back for that one case (a mark's weight
   is never below the reader's own), which ties the title and the subtitle at `large` and is therefore a change the
   reader would be making knowingly.
