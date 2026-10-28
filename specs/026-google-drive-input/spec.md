# Feature Specification: Google Drive document input

**Feature Branch**: `026-google-drive-input`

**Created**: 2026-10-28 | **Updated**: 2026-10-28

**Input**: reader's wish list item 026 — "When Kalahoo input document file, I can see google docs files
in My Drive and Shared Drive, but I cannot input them in Kalahoo Reading app."

## What this feature does

Extends the document import path to handle Google Drive files. The picker now accepts
Google Drive MIME types (`application/vnd.google-apps.*`), so Drive files appear in
the file picker. When a Drive file is picked, the app attempts to read it through
Android's ContentResolver. If the direct read fails (because DocListProvider is not
exported to third-party apps), the app opens the file in Google Drive for export,
and the user can then pick the exported local copy.

## Clarifications

### The reader's answers — asked at this stage, answered by the reader's own words (2026-10-28)

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | Which Drive sources? | **My Drive and Shared Drive** — the two roots DocumentsUI shows for Google Drive. | limiting to only one source. |
| **Q2** | What about pages/tab navigation? | **Not in MVP.** Scoped separately. | bundling it here and bloating the feature. |
| **Q3** | Does burn-after-read still apply? | **Yes.** Drive files stream, not stage — `burnCachedCopy` is a no-op for `content://` URIs. | keeping a copy of the Drive file. |
| **Q4** | Can we read Drive files directly? | **No** — DocListProvider is not exported to third-party apps (Android security restriction). The app opens the file in Drive for export. | bypassing the restriction. |

## User Scenarios & Testing

### User Story 1 — Import a Google Drive document (Priority: P1)

As a KalaHoo Reading user, I want to pick a document from Google Drive (My Drive or
Shared Drive) and have it become reading content, so I can read it aloud without
downloading it first.

**Why this priority**: the reader can already see Drive files in the picker but cannot
import them — a broken affordance that wastes the picker's own root display.

**Independent Test**: a Google Drive document is picked, its text is extracted through
the existing seam, and it becomes reading content the library, the read and the
renderer already serve.

**Acceptance Scenarios**:

1. **Given** a Google Drive document (My Drive or Shared Drive), **When** the reader
   picks it through the Import button, **Then** the app attempts to read it; if the
   read fails due to Drive's content provider restrictions, the app opens the file
   in Google Drive for export, and the reader can re-pick the exported local copy.
2. **Given** imported Drive content, **When** the reader reads it, **Then** it behaves
   exactly like any locally-imported document.
3. **Given** a Drive document with no extractable text, **When** the reader imports it,
   **Then** the OCR functions answer (FR-003).

## Edge Cases

- A Drive file the reader cannot access (permission denied) is refused with a clear error message.
- A Drive file whose MIME type is not in the accepted set is refused (same as local files).
- A network error during read is handled gracefully — the import fails, nothing is stored.
- The burn-after-read rule (SC-003) still applies — nothing of the Drive file survives on disk.

## Requirements

### Functional Requirements

- **FR-001**: The app MUST accept a document picked from Google Drive (My Drive or Shared
  Drive) through the existing Import button, extract its text, and land it as ordinary
  content — the same pipeline as local files.
- **FR-002**: Where `XFile.readAsBytes()` returns empty for a `content://` URI (Google
  Drive files), the app MUST attempt to read through Android's ContentResolver via a
  method channel, and if that fails (DocListProvider not exported), open the file in
  Google Drive for export.
- **FR-003**: The app MUST refuse a Drive pick that cannot be read (permission denied,
  network error, unsupported MIME type) with the same error message used for local files.
- **FR-004**: Imported Drive content is an ordinary content: it appears in the library
  list, is loadable, savable, editable and deletable, and is read and rendered exactly
  like hand-written content.

### Key Entities

- **GoogleDriveFile**: a picked document whose URI scheme is `content://` and authority
  identifies a Drive content provider (`com.google.android.apps.docs.storage` or
  `com.google.android.apps.photoscontent`).

## Success Criteria

### Measurable Outcomes

- **SC-001**: A Google Drive document imports successfully (after export), its text is
  extracted, and it becomes readable content — the reader can open it, read it aloud,
  and render its video.
- **SC-002**: A large Drive document is read page by page — the memory bound from 027/028 holds.
- **SC-003**: No local copy of the Drive file survives the read: the bytes are held in
  memory for reading, and the content that enters the library is the extracted text.

## Assumptions

- **A1**: The device has Google Drive installed and the reader is signed in (DocumentsUI
  shows the Drive roots only in that case).
- **A2**: The app already has the `READ_EXTERNAL_STORAGE` permission via `file_selector`;
  reading `content://` URIs from Drive requires no additional permission on Android 10+.
- **A3**: Page/tab forward/backward navigation is out of scope for this feature.
- **A4**: Google Drive's DocListProvider is not exported to third-party apps (Android
  security restriction); direct ContentResolver reads will fail with SecurityException.

## Out of scope

- Google Drive sign-in / OAuth (the reader uses the system picker, not the app's own auth).
- Page/tab forward/backward navigation on imported documents (reader's secondary request).
- Syncing imported Drive content back to Drive.
- Editing Drive files in place.
- Automatic export of Drive files without user interaction.

## What this feature does not supersede

Nothing. It extends the existing document import path (`lib/platform/document_picker.dart`)
to handle `content://` URIs; all other seams (extraction, landing, read, render) are unchanged.
