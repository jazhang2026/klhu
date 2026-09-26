# Specification Quality Checklist: Reading Video

**Purpose**: Validate specification completeness and quality before proceeding to planning
**Created**: 2026-09-25
**Feature**: [spec.md](../spec.md)

## Content Quality

- [x] No implementation details (languages, frameworks, APIs)
- [x] Focused on user value and business needs
- [x] Written for non-technical stakeholders
- [x] All mandatory sections completed

## Requirement Completeness

- [x] No [NEEDS CLARIFICATION] markers remain — none. All three questions were answered 2026-09-25 and are
      recorded in the spec's Clarifications section: the start point (the highlighted sentence, else the
      content's first), the look (the video carries the reader's typeface, character size and voices) and
      the format (a choice offered before the render — 16:9 landscape 1080p default, or 9:16 vertical). The
      assumptions each answer replaced (A1, A3, A8) were rewritten rather than left standing
- [x] Requirements are testable and unambiguous — each FR names an observable (a frame's content, a
      duration, a gap, a voice's language, the start sentence, the picture shown while a render runs, what
      a review does and does not write to the library, a kept video's reachability, the shape the file
      measures, which controls exist during a render), with no open questions left
- [x] Success criteria are measurable — duration within 2 s, 100 % of sampled sentence slots, one file per
      content, render time on the reference device, cancel leaves no file, the picture shown matching the
      frame written, what a kept and a thrown-away render leave in the library, each aspect measures as
      rendered, only Stop reachable while rendering, the share list and its no-upload rule, and a delete that
      warns before it acts
- [x] Success criteria are technology-agnostic (no implementation details) — "a standard media analyser"
      and "the device's video library" are named, not codecs-in-code or APIs
- [x] All acceptance scenarios are defined — US1: 10, US2: 4, US3: 8, plus 22 edge cases
- [x] Edge cases are identified — including the failure paths (out of space, cancelled, abandoned) and
      the two impossible-by-construction cases (a read during a render, a touch during a render)
- [x] Scope is clearly bounded — its "Out of scope" list (uploading and accounts, screen recording,
      editing, captions, batch or multiple videos, browsing every video ever made, bitrate/quality
      pickers, a video that ends before the content's end) and A8 (exactly the two aspects, no other
      formats)
- [x] Dependencies and assumptions identified — A1–A12, including A6's measured feasibility note, A9's
      reference device, A11's playback choice and A12's working-copy rule

## Feature Readiness

- [x] All functional requirements have clear acceptance criteria — FR-001/002/005 → US1 scenarios 1–3,
      FR-006/008/016 → US2 scenarios 1–3, FR-011/012 → US3 scenarios 1–4
- [x] User scenarios cover primary flows — make the video (P1), make it watchable (P2), get it off the
      phone (P3)
- [x] Feature meets measurable outcomes defined in Success Criteria
- [x] No implementation details leak into specification — the platform mechanics appear only in A6/A7,
      which is the constitution's slot for declared constraints

## Notes

- Three more answers landed on 2026-09-25 (quoted in the spec's Clarifications): share-before-keeping stays
  (measured as ~25 lines with no dependency, so there was nothing to drop), the share surface is the
  phone's own list of apps — pick one, that app uploads (FR-023) — and **every delete warns** (FR-024,
  reusing the shape the app already ships for deleting a content, F11). The honest ceiling on sharing is
  stated in Out of scope: a target the standard share list cannot express (WeChat Moments) needs that
  platform's SDK and an appid, which this constitution excludes.

- Four follow-ups were added on 2026-09-25 (the reader's own list, quoted in the spec's Clarifications):
  the render's own picture shown while it runs (FR-020), a review that plays the video before it is kept
  and only keeps on the reader's word (FR-021, which changes FR-011 — the render no longer writes into the
  gallery by itself), a record of which video belongs to which content so it can be played, shared or
  deleted later (FR-022), and sharing through the platform's sheet rather than any upload of ours
  (FR-023). Each carries its own outcomes (SC-014–SC-017) and its own edge cases.
- The four answers moved four assumptions with them: A11 (the video is watched in the app, on the
  platform's own player — still no new package, so A7 stands) and A12 (an unkept video is the app's working
  copy and can be shared from it). A reviewer should read FR-021/FR-022 as the file's life cycle: rendering
  produces a working copy, keeping promotes it into the library, deleting takes it out again.
- No clarifications are left (all three were answered 2026-09-25). The format answer turned a constant into
  a reader choice, so the plan carries two layouts — 1920×1080 and 1080×1920 — over one renderer: the
  frame, the margins and the scale that maps the reading column onto the frame differ per aspect, and those
  numbers must be derived from the chosen frame rather than hardcoded for one of them.
- A render owning the page is the second thing the plan inherits: the page's state machine gains a state
  beside READ / SPEAKING / PAUSED with its own controls (progress + Stop) and its own leave confirmation,
  reusing the read's ownership rule rather than inventing a second one.
- The Stop confirmation reuses the shape already in the app — `reading_view.dart:517`'s `_confirmDiscard()`
  (AlertDialog, Cancel + a filled confirm, ARB-keyed) — with its own strings for the render, in en and both
  zh locales as the constitution requires. Two outcomes, both receipt-able: confirm → no file for that
  content and the page idle; dismiss → the progress moves on and the render finishes normally.
- The look question was answered the other way on 2026-09-25: the video carries the reader's typeface,
  character size and voices (FR-014, A3). The consequence belongs in the plan's risk list — at the smallest
  offered size the video's text is small because that is the size the reader asked for, so the frame must
  be sized generously enough that the smallest size is still legible at 100 %, and the plan proves it on
  the smallest size rather than the largest.
- This is the first spec in the repository that needs platform-specific code (the constitution allows it,
  isolated under `lib/platform/` and its Android counterpart). A6 records the one feasibility fact that
  was verified up front (per-sentence audio to a file exists in the installed plugin's Android source);
  everything else about the frame/audio handoff belongs to the plan.
