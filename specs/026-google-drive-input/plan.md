# Implementation Plan: Google Drive document input

**Feature**: `026-google-drive-input` | **Spec**: [spec.md](./spec.md)

**Input**: reader's wish list item 026 — Google Drive files visible in picker but not importable.

## What this plan builds, in one paragraph

The Import button already shows Google Drive roots in DocumentsUI; the gap is that
`XFile.readAsBytes()` returns empty or fails for `content://` URIs that Drive files
use. This plan adds a `content://`-aware read fallback in `lib/platform/document_picker.dart`
so Drive files flow through the existing extraction seam unchanged.

## Technical Context

**Language/Version**: Dart (SDK `^3.13.3`), Flutter (Material 3), the existing `file_selector`
plugin.
**Primary Dependencies**: `file_selector` (already a dependency); Android `ContentResolver`
accessed through Flutter's platform channel (no new plugin needed).
**Storage**: the content store's own file-per-content + versioned `index.json` (008).
**Testing**: `flutter test` unit rows against the new read fallback; device walk rows on
`emulator-5554` with a Google Drive fixture (or simulated `content://` URI).
**Constraints**: one Flutter codebase (constitution I); on-device first (IV); simplicity/YAGNI (V).

## Constitution Check

- **I. Flutter Single Codebase**: PASS — the fix is in `lib/platform/document_picker.dart`,
  no new plugins.
- **II. Spec-Driven**: PASS — spec 026 is approved at the plan gate this stage closes.
- **III. Test-First**: PASS — the phases below are test-first by construction.
- **IV. On-Device First**: PASS — no account, no backend; the read runs on-device.
- **V. Simplicity**: PASS — one fallback function, one new test case.

## Project Structure

### Documentation (this feature)

```text
specs/026-google-drive-input/
├── plan.md              # This file
├── spec.md              # Approved spec
├── research.md          # Phase 0 output
├── data-model.md        # Phase 1 output
├── quickstart.md        # Phase 1 output
└── checklists/requirements.md
```

### Source Code (repository root) — the feature's own additions

```text
lib/platform/document_picker.dart   ~  the content:// read fallback
test/document_picker_test.dart      ~  new test case for Drive URI read
```

No new files: the fix lives inside the existing `DocumentPicker` implementation.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| Platform channel for ContentResolver access | `XFile.readAsBytes()` does not handle `content://` URIs from Google Drive on this Android version | none — the plugin's implementation does not expose a ContentResolver path |

## Phases

### Phase 1: Research — measure the failure

**Goal**: confirm that `XFile.readAsBytes()` fails for Google Drive `content://` URIs on the
target device, and identify the fallback path.

### Phase 2: Implementation — the content:// fallback

**Goal**: `lib/platform/document_picker.dart` reads `content://` URIs through Android's
ContentResolver when `readAsBytes()` returns empty, preserving the burn-after-read rule.

### Phase 3: Tests and closing

**Goal**: unit tests for the fallback; device walk row proving a Drive document imports end-to-end.

## Gates, and the order they run

```bash
flutter analyze                                   clean, at every phase
flutter test --concurrency=2                      green
check_tasks_format.py   specs/026-google-drive-input   → (at the tasks stage)
task_id_audit.py        specs/026-google-drive-input   → (at the tasks stage)
check_row_coverage.py   specs/026-google-drive-input   → (at the tasks stage)
check_quickstart_coverage.py specs/026-google-drive-input → (at the tasks stage)
spec_consistency.py     specs/026-google-drive-input   → no divergence
check_artifact_refs.py  specs/026-google-drive-input   → no unresolved references
```

## Risks this plan carries, and what answers each

1. **The ContentResolver path** — whether `file_selector`'s `XFile` exposes a path we can pass to
   ContentResolver, or whether we need a different approach (plugin method channel).
2. **The burn-after-read rule** — the fallback must still delete any staged copy; Drive files
   may not have a staged copy at all (they're streamed), so the rule may already hold.
3. **Permission** — whether reading `content://` URIs from Drive requires additional permissions
   beyond what `file_selector` already holds.

## What this plan explicitly does not decide

- The final wording of any new ARB keys (the tasks stage's).
- Whether to add a "Google Drive" label to the picker (out of scope — the picker already shows it).
- Page/tab navigation (reader's secondary request, scoped separately).
