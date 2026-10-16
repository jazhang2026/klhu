# Plan: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · **Ground**: `spec.md` (17 FRs, 11 SCs, 6 stories, 18 scenarios),
`research.md` (4 grounding corrections, D1-D7), `data-model.md` (INV-1..8) · **Rows**: `quickstart.md` (18)

## Summary

The app already walks the reader's picked pictures over the sentences, splitting them evenly
(`buildPictureSchedule`, `lib/video_pictures.dart:200`). This feature lets the reader **override that split**: a
pass on the reading page's own video dialog (the reader's choice, (A)) where a picture takes 0 or more **continuous**
sentences, in order; pictures holding nothing are skipped unless the unassigned tail falls back to them (012's own
even split); a picture that no longer matches the content after an edit is caught **before** the render, with a
tappable warning into the pass. With no assignment the render is 012's, frame for frame.

## Project rules this plan must satisfy

- **`flutter analyze` clean** and the suite's count written against the pre-feature baseline — the project's own
  discipline from 015-019's plans.
- **New user-visible text needs ARB keys in all four files** (`app_en`, `app_es`, `app_zh`, `app_zh_Hans`), with
  `flutter gen-l10n` and `test/l10n_keys_test.dart` green. **This is the one structural difference from 019**, which
  added no interface text and left the four files at 110 keys: this feature's pass, its two refusals and its warning
  are text, so the count moves and every artifact's structural row must say so.
- **The store copies 015's shape** (`lib/role_store.dart:48`): per content, read back on open, no new mechanism.
- **No new dependencies**; the pictures, the painter, the timeline and the audio are untouched.
- **One rule, one file**: the assignment's own rules live in one new file and are called by both the pass and the
  renderer — never re-implemented in either.

## Decisions

| # | decision | alternative, and why not |
|---|---|---|
| D1 | The reader's decision is a `List<PictureRun>` — a partition into ordered, contiguous-at-most runs | A per-sentence picture list: it cannot express "0 or more" without a second rule, and the reader's own words are the partition. |
| D2 | A run is keyed by the held picture's **path**, and stores the sentences as **content spans** | Keyed by index: `movePicture` reorders, and every run would re-point. Keyed by name: two picks can share a basename (`_safeName` only sanitises). Indices into the sentence list: the list is re-derived every render, so a content edit would re-point silently — spans make staleness *detectable* instead. **[The key moved on 2026-10-14: it is the picture's own file name, not its path — D7 and this plan's own amendment below. The span rule and the index rejection stand.]**
| D3 | `buildPictureSchedule` **stays as the no-assignment branch** (`:200`); the assignment's split is a sibling function | Edit the existing function to take the runs: the shipped path would then share code with the new one, and SC-003's "identical to 012" could only be asserted, never diffed. |
| D4 | One resolver returns `(effective runs, stale runs)`, read by both the pass and the render | Detect staleness in the render alone: the warning of FR-014 must come *before* it, from the same answer. |
| D5 | A skipped picture emits no `ScheduledPicture` — the `-` the renderer's log already prints | A zero-length frame range: it would put a picture in the file that paints nothing. |
| D5, corrected 2026-10-14 | **A skipped picture keeps 012's own UNDRAWN entry** — present in the schedule, `isDrawn == false`, `frames == 0`, printed as `-` | As first written ("emits no `ScheduledPicture`") the `-` would have had nothing to print it: that token comes from an entry that **exists** and is not drawn, which is 012's own treatment of a picture that found no sentence (`lib/video_pictures.dart`). The sentence's second half also reads wrongly: the skipped entry *is* a zero-length range (empty, at the seam where its place begins), where the alternative this row rejects was a **drawn** one (`startFrame == endFrame`), which would paint a frame. Found by T004's own case at the implement stage; the correction is in `data-model.md` §3 and `research.md` §1 too. |
| D6 | The pass rides the dialog's own seam: `_askVideoFormat`'s answer gains the runs, `_startRender` and `VideoRenderer` take them | A second entry point that re-derives the pictures and the aspect: two sources of truth for one render. |
| D7 | **The run's key is the picture's own file name** (`HeldPicture.name`), and a run re-attaches when the same file is picked again (2026-10-14) | Keyed by the held picture's *path* (D2): the tree deletes that path's directory when the prompt ends (`discardPictures`), so no run could outlive a visit. The finding and the alternatives are research D7. |

## Amendment, 2026-10-14 — the run's key, and three claims this stage found false

**The finding (verified against the tree at `a3a25e1`, not inferred).** D2's key could not work, and the requirement
built on it (FR-010, SC-006) could not hold as written:

- `storePicks` writes each pick as `<tmp>/picks_<seq>/pick_<i>_<name>` (`lib/video_pictures.dart:55-66`), and
  `_openVideoPrompt`'s `finally` calls `discardPictures(picturesDir)` the moment the prompt ends
  (`lib/reading_view.dart:2056`) — 012's own rule, and its own words: the picks are **never remembered**.
- `_pictureDirSeq` is a **page-instance** field (`lib/reading_view.dart:276`), so the directory's **name** is what
  varies: a second prompt in one page instance is `picks_1` (every stored run goes stale — the case FR-010's first
  half names), while a relaunch starts at `picks_0` and re-attached the runs **by accident**. The same reader doing
  the same thing twice gets two different answers; that is the defect, whichever way it lands.

**The reader's answer (2026-10-14, option A).** A run names its picture by the picture's own file name; the
assignment comes back into force when the same files are picked again. FR-010 and SC-006 are amended in place (no
new id — the requirement's own rule changed), research gains D7, and `data-model.md` §1/§2/§3/§6 carry the key, the
store's own shape and INV-8. **012's shipped rule is untouched**: nothing remembers a pick; what survives is the
reader's assignment. Rejected: **(B)** the assignment keeps its own copy of the pictures (a second picture source
beside the prompt's pick, and the reader's photos' bytes per content), **(C)** the assignment is a record with no
effect after the prompt closes (the reader meets "N runs no longer match" on every visit).

**Three claims this stage found false, corrected in place this pass.** Each is a claim a later row would otherwise
have spent as work:

1. **This plan's own file table gave `lib/picture_assignment.dart` the split sibling** and gave
   `lib/video_pictures.dart` "the assignment's split beside `buildPictureSchedule`" — one function, two homes. D3
   and `data-model.md` §4 put it beside `buildPictureSchedule` (it needs `PictureSchedule`, `ScheduledPicture` and
   the same frame maths), so the first row's claim is **removed**: the resolver in `lib/picture_assignment.dart`
   answers the *effective runs*; the schedule function next to `buildPictureSchedule` turns them into a schedule.
2. **`quickstart.md` row 14 said the four ARBs stay unchanged.** This plan's own structural rule says the opposite
   (the pass, its refusals and its warning are interface text, so the 110-key total moves) — the row was left over
   from a draft that added no text. Corrected in the quickstart this pass, and named here because the count it
   quotes is read by rows in other features.
3. **Nothing parsed the renderer's own `klhu render pictures=… ranges=… sentences=…` line**, which rows 6, 9, 10
   and 12 read (`lib/video_renderer.dart:286-288`; no driver under `specs/*/scripts/` matches it — 015's record of
   that line was written by hand). The walk driver gains the parser, and the task that writes the driver says so.

**What this amendment did not touch**: 012's, 015's, 016's, 017's and 019's rules. The one number that reaches
backwards is the message-key total, and the records that quote it as a standing figure are corrected with their
dates in the polish phase (the tasks file names them).

## Amendment 2, 2026-10-14 — a video is the whole content (the reader's own rule)

The reader's statement and answer at the tasks gate, verbatim: *"视频永远是从第一句开始的，最后一句结束。现在没有部分或分段视频的功能。请确定。"*
→ **"要 B"**. What the tree actually did, verified before it was changed (a throwaway probe, deleted after the run):
with the content's **last sentence highlighted** — a tap, which is the reader's own gesture and which puts 010/011's
position in force — the renderer's own line read

```
klhu render pictures=0 ranges= sentences=1
klhu render slot=0/2 frame=0/84 … span=22..31 text=9
```

so the video held **one** sentence, not the content's three. That is 012's FR-004's first half, shipped and
receipted (`test/video_timeline_test.dart`'s four start-point cases), and this feature supersedes it.

**The rule now (FR-017, SC-011, User Story 6)**: a video is the whole content — the content's first sentence to its
last — and 011's position decides only where a **read** starts. Where the rule lives, and why: the **page**
(`lib/reading_view.dart`'s `_startRender` and `_assignSentences` pass the content's first sentence) rather than the
renderer, because the timeline's own API still starts where it is told and 012's unit cases stay true — the
alternative (the renderer ignoring its `position`) is recorded and rejected, because it would make a parameter dead
and re-cut 012's cases for no reader-visible gain. The dialog's own pass follows it: it shows the whole content's
sentences, so a highlight can no longer hide sentences from the assignment.

**Ripple, and what is not swept**: 012's `spec.md`, `research.md`, `data-model.md` and `quickstart.md` are the
record of what was approved on 2026-10-01 and are **left as written**; the pointer is one bullet in 012's
`tasks.md` `## Superseded by later specs`, naming FR-017 and the sentence it falsifies. Nothing else moves: no
shipped device row ever recorded a render started from a highlight (grepped: 012's own record has no `sentences=` or
`slot=0/` lines, and every other spec's renders show `span=0..`), so 012's walk needs no re-cut.

## Files

| file | state | what it carries |
|---|---|---|
| `lib/picture_assignment.dart` | **new** | `PictureRun`, the resolver (`assignmentsFor` — the effective runs, the stale runs and the refusal reasons), and the drag/un-assign predicates — the whole of D1/D4/D5/D7's rules |
| `lib/picture_assignment_store.dart` | **new** | the per-content record, 015's shape (`lib/role_store.dart`) |
| `lib/picture_assignment_screen.dart` | **new** | the pass (A): the pictures in order, each with its run, the drag, the un-assign, the two refusals |
| `lib/video_pictures.dart` | extended | the assignment's split beside `buildPictureSchedule` (D3) — the one home for it; **`buildPictureSchedule`'s own body unchanged** |
| `lib/video_renderer.dart` | extended | `runs` in, handed to the schedule builder (`:151-171`, `:448-458`) |
| `lib/reading_view.dart` | extended | the dialog's seam (`_askVideoFormat` `:1880`, `_startRender` `:1857`/`:2063`), the stale warning before the render, and the call into the pass |
| `lib/l10n/app_{en,es,zh,zh_Hans}.arb` + the generated Dart | extended | the pass's labels, the two refusals, the warning |
| `test/picture_assignment_test.dart` | **new** | rows 1, 2, 4, 5 (the resolver's six shapes, the stale rule, the predicates) |
| `test/picture_assignment_store_test.dart` | **new** | row 15 (the store's own contract: one key per content, a tolerant read, no entry for nothing assigned) |
| `test/video_pictures_test.dart` | extended | row 3 (the schedule seam, as ranges) |
| `test/video_renderer_test.dart` | extended | the runs reach the renderer and its log line keeps its shape |
| `test/reading_view_video_assignment_test.dart` | **new** | the dialog's own seam: the answer carries the runs, the warning comes before the render |
| `specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` + fixture | **new** | the device walk (rows 6-13, 16-18), importing **012's** `klhu_walk_video` for the pick (it is the only driver that pushes pictures and drives the platform's own file dialog: `make_pictures`/`push_pictures`/`choose_pictures`/`picture_at`) and 016's `klhu_walk_step` (through 019's) for the read's mechanics; it also gains the parser for the renderer's own `pictures=… ranges=…` line |

## Ripple — what this feature touches that it did not write

- **`buildPictureSchedule`'s callers**: one (`lib/video_renderer.dart:458`). The new branch is chosen one level
  above it, so the function's own signature and body do not move — the structural row diffs exactly that.
- **The renderer's log line** (`:286`): its fields keep their names (`pictures=`, `ranges=`), which is what the device
  rows read. No field is added, because the assignment is the *ranges* it already prints.
- **The l10n count**: 110 → 110 + this feature's keys, in four files. Every receipt that quotes 110 (019's among
  them, and this spec's own structural wording) is a figure about *019's* tree, not this one — the tasks stage must
  state this feature's own number, and the structural row must quote it. **The two standing figures a re-walk would
  read as current** are corrected with their dates in the polish phase: `specs/019-head-tags/quickstart.md`'s
  structural row's expected `110`, and `specs/019-head-tags/tasks.md`'s Status baseline line (019's and 017's
  *dated measurements* stay as they are — they were true of their own trees).
- **Nothing shipped is amended**: no rule of 012's, 015's, 016's, 017's or 019's changes, so no closed feature's
  record gains a section (contrast 019, which amended 017's comment rule and had to say so in 017's own record).

## Boundaries

- **In**: the assignment, its store, its pass, its rules, its warning, and the schedule seam.
- **Out**: how pictures are picked, cropped or toned; the sentences, the voices and the audio; the video's own
  container, aspect, pacing or the review screen after a render; editing a video already written (spec's Out of
  scope); reordering sentences; and a picture-per-sentence transition.
- **The one visual shape left to the plan's own pass, not this document**: the inside of the pass's page (how a run
  is shown and edited) — specified as behaviour in the rows, drawn in `ui-sketch.html`, and to be settled in the
  implement pass with a screenshot for the reader, the way 019's row 10 settled the ladder's look.
