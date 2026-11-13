# Quickstart: Tap-to-read — remove the Read button

## Prerequisites

- Flutter stable; `flutter pub get` already run.
- A device or emulator (`klhu` AVD) for the walk; widget tests need none.

## Automated verification

```bash
cd ~/Documents/GitHub/Projects/klhu
flutter analyze --no-pub
flutter test --concurrency=2
```

Expected: analyzer clean; all tests pass, including the rewritten step/continue suites.

## Widget-level scenarios (what the tests prove)

1. **Tap reads one sentence** — tap a sentence in the sample text → `RecordingReader.spoken` contains only
   that sentence; highlight stays on it after the read ends; no Read-button tooltip exists.
2. **Tap repeats** — tap the highlighted sentence again → same sentence spoken again.
3. **Long-press reads a paragraph** — `longPressAt` inside a paragraph → the whole paragraph's range is
   spoken; paragraph highlight remains.
4. **⏭ starts from next step** — tap-read sentence k, press Continue Read → first speech starts at
   sentence k+1.
5. **Wrap** — Continue Read on a short text → `klhu speak` sequence repeats from sentence 1 without another
   press; Stop ends it (`fake.stops` increments, no further speeches).
6. **Pause inside wrap** — pause mid-loop, resume → interrupted sentence repeats, loop continues and wraps.
7. **Inter-unit guard** — a >4000-char (or paged) content: pause during unit 1 → no unit-2 speech until
   resume; resume finishes unit 1's remainder then continues unit 2.

## Device walk

1. Open any saved content in READ mode. Confirm the toolbar shows **no** play/Read button — only Continue
   Read, Pause/Resume (while reading), Stop, Edit.
2. Tap a sentence → it highlights, scrolls into view if needed, and is read; it stays highlighted at end.
3. Tap it again → repeats. Tap another sentence → that one reads.
4. Long-press a paragraph → whole paragraph reads, paragraph stays highlighted.
5. Press Continue Read → reads to the end, then keeps going from the first sentence. Press Pause → parked;
   Resume → continues; press Stop → all speech ends and nothing restarts.
6. `adb logcat | grep 'klhu speak'` shows the repeating sentence sequence during the wrap.
