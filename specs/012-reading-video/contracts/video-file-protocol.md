# Contract: the file channel (Dart → platform)

**Feature**: `012-reading-video` | **Dart side**: `lib/platform/video_encoder.dart` (the same interface
object) | **Kotlin side**: `VideoFileStore.kt` | **Spec**: FR-011, FR-012, FR-022, FR-023, FR-024 |
**Decisions**: D7, D11, D13

Where a video lives, how it is handed to the phone's share list, and how it is removed. Keeping is the only
call that writes into the device's video library (FR-021).

Channel: `klhu/video_files` (a `MethodChannel`).

## `isAvailable() → bool`

Whether this platform can render, keep and play a video at all. Android with the channel registered answers
`true`; iOS answers `false` until its half exists (D8) — the reading page offers nothing when it is `false`.

## `keep(workingPath, displayName, previousUri?) → {uri, name}`

Promotes the working copy into the device's video library under `displayName` (FR-011).

- **API 29+**: a `MediaStore` insert into `Movies/Klhu/` with `IS_PENDING` set while writing and cleared
  after, and the entry published only once the bytes are complete. (`IS_PENDING` is also D11's fallback for
  sharing a working copy if `FileProvider` ever proves unavailable.)
- **API 24–28**: the file is written to the public Movies directory and announced with
  `MediaScannerConnection.scanFile` (the manifest declares `WRITE_EXTERNAL_STORAGE` with
  `maxSdkVersion="28"`, D7).
- `previousUri`, when given, is deleted **after** the new file is in place, so a failed keep never leaves the
  reader with nothing (FR-012).

Fails (no exception escaping to Dart) if the file cannot be written; the reader is told and nothing is kept.

## `share(source) → void`

Hands the file to the phone's own share surface — `ACTION_SEND` with the file's URI, the video MIME type and
`FLAG_GRANT_READ_URI_PERMISSION` — and returns as soon as the list is shown (D13).

- A **kept** video is shared by its library URI, which needs no provider.
- A **working copy** is shared through AndroidX's `FileProvider` (`content://<applicationId>.fileprovider/…`),
  which is why the manifest carries the provider entry and a paths resource (F10, D11).

The app performs no upload, holds no account/appid and bundles no platform SDK (FR-023); the chosen app does
whatever it does with the file.

## `delete(uri) → bool`

Removes the file from the device's video library (FR-022). Returns whether it is gone afterwards — `true`
also when it was already gone, so a stale record can be cleaned up without an error. **Callers must have
warned first** (FR-024): this call itself asks nothing, which keeps the confirmation in the shared code where
it is testable.

## `exists(uri) → bool`

Whether a video the record names is still in the library. A `false` is what makes a record stale: the app
forgets the entry and offers to record again (FR-022).

## Invariants

- Nothing but `keep` writes into the video library; cancelling, failing or throwing a render away never
  creates or deletes a library entry (FR-009/FR-021).
- `keep` never leaves two files for one content: the replacement order is write-then-delete (FR-012).
- `share` works on a working copy and on a kept video, and never implies keeping (A12).
- Every call is local: no upload, no account, no network (FR-013/FR-023).
