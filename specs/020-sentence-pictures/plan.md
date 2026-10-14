# Plan: sentences assigned to pictures

**Feature**: `020-sentence-pictures` · **Ground**: `spec.md` (16 FRs, 10 SCs, 5 stories, 17 scenarios),
`research.md` (4 grounding corrections, D1-D6), `data-model.md` (INV-1..7) · **Rows**: `quickstart.md` (14)

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
| D2 | A run is keyed by the held picture's **path**, and stores the sentences as **content spans** | Keyed by index: `movePicture` reorders, and every run would re-point. Keyed by name: two picks can share a basename (`_safeName` only sanitises). Indices into the sentence list: the list is re-derived every render, so a content edit would re-point silently — spans make staleness *detectable* instead. |
| D3 | `buildPictureSchedule` **stays as the no-assignment branch** (`:200`); the assignment's split is a sibling function | Edit the existing function to take the runs: the shipped path would then share code with the new one, and SC-003's "identical to 012" could only be asserted, never diffed. |
| D4 | One resolver returns `(effective runs, stale runs)`, read by both the pass and the render | Detect staleness in the render alone: the warning of FR-014 must come *before* it, from the same answer. |
| D5 | A skipped picture emits no `ScheduledPicture` — the `-` the renderer's log already prints | A zero-length frame range: it would put a picture in the file that paints nothing. |
| D6 | The pass rides the dialog's own seam: `_askVideoFormat`'s answer gains the runs, `_startRender` and `VideoRenderer` take them | A second entry point that re-derives the pictures and the aspect: two sources of truth for one render. |

## Files

| file | state | what it carries |
|---|---|---|
| `lib/picture_assignment.dart` | **new** | `PictureRun`, the resolver (`assignmentsFor`), the split sibling of `buildPictureSchedule`, and the drag/un-assign predicates — the whole of D1/D2/D4/D5's rules |
| `lib/picture_assignment_store.dart` | **new** | the per-content record, 015's shape (`lib/role_store.dart`) |
| `lib/picture_assignment_screen.dart` | **new** | the pass (A): the pictures in order, each with its run, the drag, the un-assign, the two refusals |
| `lib/video_pictures.dart` | extended | the assignment's split beside `buildPictureSchedule` (D3); **its own body unchanged** |
| `lib/video_renderer.dart` | extended | `runs` in, handed to the schedule builder (`:151-171`, `:448-458`) |
| `lib/reading_view.dart` | extended | the dialog's seam (`_askVideoFormat` `:1880`, `_startRender` `:1857`/`:2063`), the stale warning before the render, and the call into the pass |
| `lib/l10n/app_{en,es,zh,zh_Hans}.arb` + the generated Dart | extended | the pass's labels, the two refusals, the warning |
| `test/picture_assignment_test.dart` | **new** | rows 1-5 (the resolver's six shapes, the stale rule, the predicates) |
| `test/video_pictures_test.dart` | extended | row 3 (the schedule seam, as ranges) |
| `test/video_renderer_test.dart` | extended | the runs reach the renderer and its log line keeps its shape |
| `test/reading_view_video_assignment_test.dart` | **new** | the dialog's own seam: the answer carries the runs, the warning comes before the render |
| `specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` + fixture | **new** | the device walk (rows 6-13), importing 019's driver for the mechanics |

## Ripple — what this feature touches that it did not write

- **`buildPictureSchedule`'s callers**: one (`lib/video_renderer.dart:458`). The new branch is chosen one level
  above it, so the function's own signature and body do not move — the structural row diffs exactly that.
- **The renderer's log line** (`:286`): its fields keep their names (`pictures=`, `ranges=`), which is what the device
  rows read. No field is added, because the assignment is the *ranges* it already prints.
- **The l10n count**: 110 → 110 + this feature's keys, in four files. Every receipt that quotes 110 (019's among
  them, and this spec's own structural wording) is a figure about *019's* tree, not this one — the tasks stage must
  state this feature's own number, and the structural row must quote it.
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
