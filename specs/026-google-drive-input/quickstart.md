# Quickstart: how 026 is walked

**Feature**: `026-google-drive-input` | **Plan**: [plan.md](./plan.md)

Rows for the plan's phases, in the order they run. Every row names the **one**
thing it proves, the command that runs it, and the numbers it is expected to land on.

## Unit rows

### 1. The content:// read fallback — a Drive URI yields bytes — [unit]

Test: `flutter test test/document_picker_test.dart` (the picker's own table).
Steps: simulate a `content://` URI pick; verify `readAsBytes()` fallback reads
the content through ContentResolver; verify `burnCachedCopy` is a no-op.
Expected: the fallback yields non-empty bytes; no cache copy is attempted.
Proves FR-002, FR-003, SC-003.

### 2. Imported Drive content is ordinary — [unit]

Test: `flutter test test/document_input_test.dart` (the seam's own table).
Steps: pass Drive-extracted bytes to `extractText`; verify the text enters the
content pipeline like any other extracted text.
Expected: the text lands as `origin: user` content, readable and renderable.
Proves FR-001, FR-004, SC-001, SC-002.

## Closing

- The closing pass re-takes the counts (tests, ARB keys, artifact checkers) and writes the receipts.
