# Data model: Google Drive document input

**Feature**: `026-google-drive-input` | **Date**: 2026-10-28

## Changes to existing entities

No new entities. The existing `PickedDocument` and `DocumentPicker` interfaces are
extended implicitly: the `read()` function now handles `content://` URIs.

## New internal behavior

### `PickedDocument.read()` for `content://` URIs

When the picked file's URI scheme is `content://` (Google Drive, or any other
content provider):
1. Try `file.readAsBytes()` first (fast path for local files).
2. If the result is empty and the URI scheme is `content://`, fall back to
   reading through Android's ContentResolver.
3. The bytes are returned the same way; the caller (`extractText`) is unchanged.

### `burnCachedCopy()` for `content://` URIs

When the picked file's path is a `content://` URI:
- `burnCachedCopy` returns `false` immediately (no staged copy to delete).
- This is correct: Drive files are streamed, not staged.

## What does not change

- `extractText` — unchanged; it receives bytes and routes by kind.
- `saveImported` — unchanged; it stores text in the content store.
- The read pipeline — unchanged; imported Drive content is ordinary content.
