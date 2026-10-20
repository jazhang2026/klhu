# Contract: the remembered motion choice

**Feature**: `023-video-background-motion` | **Store owner**: `lib/video_motion_store.dart` | **Spec**: FR-009, A5

The one thing this feature persists: whether the reader's pictures move in a video. One choice per device, kept in the
store the app already uses for the remembered format, the voice picks, the interface language and the reading
appearance.

| Item | Value |
|---|---|
| Store | `shared_preferences` (the app's existing store; no new store is added) |
| Key | `video_motion` |
| Domain | `on` \| `off` |
| Default | `off` |
| Written | once per confirmed video prompt |
| Read | once per video prompt, when it opens |

**Why a key of its own, and not a field of `video_aspect`.** 012's own record contract
(`specs/012-reading-video/contracts/video-aspect-format.md`) enumerates that value's domain as `landscape | vertical`
and states that any other value reads as the default. A compound value (`landscape+motion`) would falsify both, and
every reader of that contract — including the rows that read it back off the device — would silently read the
default. The two choices are independent (every format can move, or not), so they are two keys.

## Read rules

1. A missing key returns `off` — the first ever prompt offers the effect **unswitched**, which is the item's 「可选」.
2. Any value outside `on | off` returns `off`, without an error and **without rewriting** the stored value (the
   aspect store's own rule, `lib/video_aspect.dart:50`).
3. A store that throws (no persistence layer, a locked file) returns `off` and logs one line
   (`klhu video motion unreadable: …`); nothing blocks a prompt or a render.
4. The read happens when the video prompt opens — never at app start, so the launch path gains no new work.

## Write rules

1. Exactly one write per **confirmed** prompt, at the moment the format is saved (`lib/reading_view.dart:1975`).
2. A cancelled or dismissed prompt writes nothing: the record it found is the record it leaves.
3. The write replaces the previous value; the key never gains a second shape (no compound values, no JSON).
4. A failed write is swallowed (the existing behaviour): the render proceeds with the value in memory, and the next
   prompt falls back to the stored record or to `off`.

## Error and repair states

| state | what the reader sees | what the store holds after |
|---|---|---|
| key absent | the prompt, switch off | still absent (a confirm writes `off` explicitly) |
| key holds `garbage` | the prompt, switch off; one `debugPrint` | still `garbage` — never rewritten outside a confirm |
| store throws on read | the prompt, switch off | unchanged |
| store throws on write | the render, with the chosen effect | the previous value |

## Invariants

- The stored value is one of `on`, `off`, or the key is absent.
- The choice is per device: not per content, not per locale, not per format. Changing the format never changes it,
  and changing it never changes the format's own record.
- A render's answer is fixed at its start: no frame of one render can be painted under a different choice.
- Nothing in 012's record moves. `video_aspect` keeps its domain, its default and its single-value invariant; a
  device carrying one key and not the other is a legal state and renders today's video.
