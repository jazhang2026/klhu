# Research: Google Drive document input

**Feature**: `026-google-drive-input` | **Date**: 2026-10-28 | **Spec**: [spec.md](./spec.md)

## Baseline

```
flutter analyze                                   → No issues found!
flutter test --concurrency=2                      → 932 tests, All passed!
```

## §1 What the tree already carries

| need | where | what it answers |
|---|---|---|
| the pick | `lib/platform/document_picker.dart` | `file_selector`'s `openFile()` — shows Google Drive roots in DocumentsUI on Android |
| the read | `lib/platform/document_picker.dart:117` | `file.readAsBytes()` — works for local files; **unknown for `content://` Drive URIs** |
| the burn | `lib/platform/document_picker.dart:42` | `burnCachedCopy(path)` — deletes platform-staged copies inside the app cache |
| the extraction | `lib/document_input.dart` | `extractText(bytes, kind)` — routes by kind to platform libraries |

## §2 The failure mode (measured 2026-10-28)

When the reader picks a Google Drive file through DocumentsUI:
- `file_selector` returns an `XFile` whose `.path` is a `content://` URI
- `file.readAsBytes()` on this URI: **returns empty bytes on this emulator** (android-36)
  — the `content://` stream is not readable through the standard Dart `File` API
- `burnCachedCopy(file.path)`: no-op because the path is not inside the app cache

The existing import path (`lib/reading_view.dart:906`) calls `picked.read()` which calls
`file.readAsBytes()`. When this returns empty, `extractText` returns `''`, the app
shows "No text could be extracted from this document", and the import fails silently.

## §3 Decisions

### D1 — Add a `content://` read fallback in `document_picker.dart`

When `readAsBytes()` returns empty and the path scheme is `content://`, read through
Android's `ContentResolver` via a small method channel call. This follows the same
pattern the app already uses for `flutter_pdf_text` and `flutter_native_ocr`.

### D2 — No new plugin; extend the existing platform channel pattern

The app already has platform-specific code in `lib/platform/` behind method channels.
The ContentResolver read is added as a new method in the same pattern — no new
dependency, no new plugin.

### D3 — Burn-after-read already holds for Drive files

Drive files are streamed, not staged. `burnCachedCopy` is correctly a no-op for
`content://` URIs (the path is outside the app cache). No change needed.

## §4 Risks and reservations

- **R1** — whether the ContentResolver approach works on all supported Android versions.
- **R2** — whether additional permissions are needed (likely not; `file_selector`
  already grants read access to the picked URI).
- **R3** — page/tab navigation (reader's secondary ask) is out of scope.

## §5 What this research does not measure

The actual Google Drive import on a real device with a signed-in Drive account is
measured at the walk; nothing here re-measures a closed feature's behaviour.
