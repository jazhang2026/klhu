# Contract: the remembered video aspect

**Feature**: `012-reading-video` | **Store owner**: `lib/video_aspect.dart` | **Spec**: FR-007, A8

One choice per device, kept in the store the app already uses for voice picks, interface language and read
positions.

| Item | Value |
|---|---|
| Store | `shared_preferences` (the app's existing store; no new store is added) |
| Key | `video_aspect` |
| Domain | `landscape` \| `vertical` |
| Default | `landscape` (16:9 1920×1080) |

**Derived, not stored** (the frame and the layout follow from the value, so a change of layout rules never
needs a migration):

| `aspect` | Frame | Frame rate | Layout consequence |
|---|---|---|---|
| `landscape` | 1920×1080 | 30 fps constant | a narrower reading column than the frame allows, with wider margins (A3) |
| `vertical` | 1080×1920 | 30 fps constant | a column close to the phone's own shape, so the chosen character size reads naturally (A3) |

## Read rules

1. A missing key returns the default (`landscape`) — the first ever render asks and offers `landscape`.
2. Any value outside the domain returns the default, without an error and **without rewriting** the stored
   value (the app's existing store behaviour).
3. The read happens when the reader starts a render (the choice offered before it, FR-007) — never at app
   start, so nothing new runs on the launch path.

## Write rules

1. Exactly one write per confirmed choice, on the reader's confirmation of the choice they made (not per
   keystroke, not per render start).
2. The write replaces the previous value; the store never grows a second aspect key.
3. A failed write is swallowed (the app's existing store behaviour): the render proceeds with the value in
   memory, and the next launch falls back to the default rather than failing.

## Invariants

- The stored value is one of the two domain values, or the key is absent.
- A video's own frame is decided at its render's start; changing the remembered choice never alters a file
  that already exists.
- This key is not content-specific and not locale-specific: the same choice governs every content in every
  interface language.
