# Specification Quality Checklist: Video Background Motion

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-10-19 | **Amended**: 2026-10-19 at the plan gate (the reader's answer `B` — FR-013 and the rewrites)
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details as *decisions* — the file names and line numbers appear only as **evidence for what the
      app already does** (`lib/video_painter.dart:432` draws the picture cover-cropped, `_coverSource` at `:681`;
      `lib/video_renderer.dart:318-330` reuses one painted picture per visual state; the plate/ink decision at
      `lib/video_painter.dart:409-424`), never as a design instruction. The requirements name observables: what the
      frames show, how far they may move, what the words do, what the reader chooses
- [x] Focused on user value and business needs — the item's own three lines are the spine, quoted verbatim in
      `Input` (substring-checked against `text.txt`, three lines, not one reflowed)
- [x] Written for non-technical stakeholders — "the picture breathes", "the frame never shows a gap", "the words do
      not move"; the mechanism (the inset framing, source-rect offsets, frame progress) is confined to the
      Clarifications' grounding
- [x] All mandatory sections completed — header (Feature Branch / Created / Status / Input), Clarifications,
      User Scenarios & Testing, Edge Cases, Requirements + Key Entities, Success Criteria, Assumptions, Out of scope,
      and the feature's own supersession/receipts section

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — **zero** (`grep -c 'NEEDS CLARIFICATION' spec.md` → 0). The one
      genuinely ambiguous word in the item — "(可选)" — is settled as a decision with its refused alternative
      (Clarifications, first entry), because the reader's list is written and this stage is expected whole
- [x] Requirements are testable and unambiguous — each FR names an observable: a window that moves between frames
      (FR-001), the offered directions (FR-002), the bound and how it is measured (FR-003), the return to the starting
      framing (FR-004), "no frame shows the background where the picture is" (FR-005), the frame-driven motion
      (FR-006), the words and plates unchanged (FR-007), a picture's own start and continuity (FR-008), the reader's
      choice and its default (FR-009), the invariants the render keeps (FR-010/FR-011), the evidence line (FR-012) and
      the inset framing that makes the room (FR-013).
      **13 FRs, 6 SCs, 6 assumptions, 4 stories, 11 acceptance scenarios, 9 edge cases** — counted mechanically
      (`grep -c`), not by eye; 12 FRs at the specify stage, 13 since the 2026-10-19 amendment's FR-013 (no new
      scenario was needed: `US2`'s third was re-cut to witness it)
- [x] Success criteria are measurable — the displacement bound and the no-gap rule read off **rendered frames**
      (SC-002), the resting framing recurring within 3 s (SC-003), a zero pixel difference on the text area (SC-004),
      ≤ 1.5× of 012's measured 60.6 s (SC-005), and 012's own frame/duration/audio checks re-read (SC-006)
- [x] All acceptance scenarios are independently testable — US1 needs one picture and a two-sentence content; US2
      needs the frame sampler; US3 needs only the setup surface and the stored record; US4 needs two pictures and one
      picture spanning two sentences
- [x] Edge cases are named rather than left to the plan — nine of them, including the two that decide the design: a
      picture with **no cover-crop slack** (its room comes entirely from FR-013's inset) and a picture of **exactly**
      the frame's aspect (cover crop = the whole picture; the frame must not letterbox to fake room)
- [x] Scope is bounded — `## Out of scope` refuses transitions, text/plate motion, per-picture amplitude, an editing
      UI, a true zoom-out, audio/rate/duration changes and any reproducibility rule
- [x] Dependencies and integrations stated — no new dependency, no network call; the only integration is 012's video
      prompt (`lib/reading_view.dart:2003`) and the app's per-device store (`lib/video_aspect.dart:63`), both named
      with what they will need to carry — a **sibling key**, not a field of 012's record

## Notes

**The judgment calls a reviewer should argue with, in the order they cost something.**

1. **"(可选)" is read as the reader's toggle, defaulting to *off*.** The alternative — always on because they asked for
   it — is refused in Clarifications with its reason (a kept video is an artefact; the app does not change one
   unasked). **The cost of this reading**: a new choice in 012's video prompt, a sibling key in the app's per-device
   store (012's own record untouched), one string in each of the four ARBs, and a row of dialog that 021's
   prompt-reading walk rows will see. If the reader meant "just make it happen", FR-009 and the surface it describes
   fall away and the price halves.
2. **The motion's price is 012's frame-reuse, and it is named as a number to re-take.** Today the renderer paints one
   picture per visual state and reuses it (`lib/video_renderer.dart:318-330`); a motion makes every frame a new state.
   SC-005 sets the budget at **≤ 1.5 × 60.6 s** for a one-minute render — **my number, not the reader's**, chosen so
   the feature can be judged before it is built. A reviewer should challenge the factor, not just the measurement.
3. **Re-cut 2026-10-19 (the plan gate's amendment, FR-013).** This line used to argue that 「远」 is anchored *inside*
   the crop. It still cannot go past the crop, but it is now a direction of its own, travelling outward from the inset
   framing and stopping at the cover crop. A true zoom-out — below the cover crop — is still refused in
   Clarifications, and with it the letterboxing the item's premise forbids.
4. **Re-cut 2026-10-19 (the plan gate's amendment, FR-013).** This line used to accept that a picture with no slack on
   an axis "does not move on that axis", and that a 16:9 photo in a 16:9 frame therefore gets only the zoom. The
   reader's answer at the gate was `B`: the framing is **inset first**, so every picture has all ten directions.
   **The cost is theirs to judge and it is written into the spec**: with the effect on, a picture is presented
   1.20 × tighter than the cover crop (69.4 % of its area). A reviewer should push on the *inset factor* (why `5/6`,
   why not `0.8` or equal on-screen pixels), not on whether the room should exist — that question is answered.
5. **"Random" is not seeded.** The evidence this feature owes is the bound, never a particular direction (SC-002/SC-003
   read off frames). A reviewer who wants reproducible renders is asking for a rule no shipped requirement carries;
   that is a different spec.
6. **The words are required to be pixel-identical, and that is the strictest line in the document.** It is what stops
   the plate's colour flickering as the picture slides under it (FR-007, SC-004). It also constrains the plan: the
   tone must be read once per slot, not per frame — and A4 names the case where a small amplitude could still straddle
   a plate/ink boundary, which the plan owes a measurement for.

## Notes added by the 2026-10-19 amendment (FR-013, FR-002/003/005/008, A2, US2's third scenario)

- **What changed, and why it is the reader's.** The specify stage read the tree's cover crop as the wall: a picture has
  room on one axis or none, so the item's diagonals could be offered to nobody and 「远」 could only be a return leg.
  At the plan gate that finding was put as options, and the reader answered **B** — inset the framing before the
  picture moves, and read the bound on the frame's own dimension. Their words are quoted in the Clarifications entry.
- **What it buys**: all ten directions for every picture, the bound expressed on what the viewer actually sees (192 px
  across, 108 px down on a 16:9 frame; the two swap on 9:16), and one rule that needs no aspect branch.
- **What it costs**: a 1.20 × tighter framing with the effect on (`k = 5/6`, 69.4 % of the cover crop's area), and a
  plate whose colour is read over the inset framing — so an on-render's plate can differ from an off-render's for the
  same picture. Both are stated in the spec, not only here.
- **What it does not touch**: `SC-001` (the off path is the pre-feature file, frame for frame), `SC-005`'s ceiling,
  FR-010's frame count/rate/duration/audio, the store's shape, and the words/plates' pixel identity within a slot.
- **Owed before this amendment can be called done** (named here, not implied): the four locales' one new string, a
  unit row per invariant the inset creates, the device rows the quickstart numbers, and the closing pass's re-count of
  `13 FRs` in every artifact that quotes it.

**What this stage does not answer, on purpose.** How the direction is drawn, how the cycle is shaped in time, and where
the amplitude lives in the painter are the plan's; the spec fixes only what a reader can see and what a row can
measure.

## Notes added by the tasks and implement stages (2026-10-19, `T023` closed 2026-10-20)

- **The rows landed where the plan said**: eight unit rows and six device rows, all green, `T023` included once its
  second half had a build to compare against — the `## Status` in `tasks.md` carries the counts and `breakpoint.md` each
  row's own receipt.
- **Two levers were spent to meet `SC-005`**, both of them D9's own rungs: the raw-frame channel (`video_encoder.dart`
  and its Kotlin half) and `motionQuantum = 6`. The criterion was reached at **1.43 ×**; the drift now updates 12 times
  per 2.4 s cycle, and whether that still reads as drift is the reader's judgement on row 10's still.
- **`SC-005`'s wording was re-cut** in the spec from an absolute wall clock to the ratio — because 012's reference
  content is no longer what the app ships.
- **`SC-001`'s wording was re-cut** too, and for the same kind of reason: it promised 012's row 49 at `40/40`, and row 49
  has 41 checks, one of which 020's own "Assign sentences" prompt row had made impossible to pass — on both builds. The
  reader's call was to re-cut that assertion rather than write the red into the criterion, so 012's row 49 reads
  **41/41** again and the spec carries **42/42 and 41/41** beside the proof that stands: the off render's frames are the
  base build's, frame for frame (`breakpoint.md` row 14).
- **What the amendment's owed list still holds**: nothing of `FR-013`'s work is missing; the store key, the four
  locales, the ten directions and the inset framing are all in the tree and witnessed by rows.

