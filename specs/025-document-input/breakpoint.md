# Breakpoint: document input (025)

**Date**: 2026-10-26 — quickstart row 4 walked at 16:23 PDT, then re-walked at 16:53 PDT after the reader's own
reading of SC-003 (in-memory only, burned after the read) landed the burn in the picker.
**Build driven**: `build/app/outputs/flutter-apk/app-debug.apk`, built 16:51:27, installed on `emulator-5554` at
16:51:29 (`dumpsys package … lastUpdateTime`), with no file under `lib/` or `android/app/src` newer than it. (The
16:23 run drove the 15:35:20 build; its numbers stand for that build.)
**Status**: Phase 1–6 closed. Row 4 **WALKED — PASS** (21/21 checks, exit 0). Rows 1–2 pass at unit level; row 3
**NOT WALKED** (no OCR implementation exists). Three findings (F2–F4) and four items owed, below; F1 is fixed.

## The walk, row by row

| quickstart row | state | evidence |
|---|---|---|
| 1 — the pick → read seam answers for a text document | **PASS** (unit) | `test/document_input_test.dart`, inside the 908-case suite: the supported kinds, the refusal of `rtf`/`null`/`''`, the landing as `origin: user` |
| 2 — the page/segment choice | **PASS** (unit) | the same table: pages own their text, an unsegmented text is cut into bounded segments, `'   '` yields none |
| 3 — the OCR path | **NOT WALKED** | `requiresOcr()` is a predicate with a test; nothing OCRs a document (owed item 2) |
| 4 — the import end to end | **WALKED — PASS**, 20/20, exit 0 | `python3 -u specs/025-document-input/scripts/klhu_walk_document.py 4`; verbatim lines below |
| structural (T007) | **PASS** | the numbers below |

## Row 4's receipts — the reader's own path, no seeding

The driver was re-cut in this pass: the earlier version **seeded** the content store (014's `seed()`), so it drove the
store and the segmenter and never the import — the document picker, the extraction and the landing were all bypassed.
Row 4 now walks what the feature is: a real file on the device's storage, the app's own import tab, the platform's own
file dialog from its roots to the file, and then the content the app made.

```
$ /usr/bin/python3 -u specs/025-document-input/scripts/klhu_walk_document.py 4
   PASS 4: the device holds a build of this tree — APK newer than lib/l10n/app_localizations.dart (16:51:27)
   the store before the import: 6 contents, 8 files
   cleared 2 cache cop(ies) left by earlier runs
   PASS 4: the document is a real file on the device's own storage — -rw-rw---- … 383 2026-10-26 16:51 /sdcard/Download/klhu025_import.txt
   PASS 4: the reading page offers the import (FR-001) — the page draws 'Import document'
   PASS 4: the platform's picker opened on the app's tap (FR-001) — DocumentsUI, on its own surface
   PASS 4: the document is listed in the device's Downloads, by its own name — ['Preview the file klhu025_import.txt', 'klhu025_import.txt']
   PASS 4: the picked document's text reached the reading page, whole — 140 chars painted, the document holds 140
   PASS 4: the import added exactly one content to the library (FR-004) — 6 before, 7 after, new: ['c_1793058730335_80d1']
   PASS 4: the imported content is an ordinary user content (FR-004) — {'origin': 'user', 'language': 'zh-Hans', 'name': '深秋的夜来得很早。 (4)'}
   PASS 4: the content that landed is the document's extracted text (SC-001, SC-003) — 141 chars stored, 141 in the document
   PASS 4: no copy of the picked document in the app's own store (SC-003) — the store root holds 9 files, none of them the document
   PASS 4: the document's staged copy is burned once its bytes are read (SC-003) — the app's cache holds no copy of the document
   PASS 4: the imported page offers the read from the top — it draws 'Continue Read'
   the app logged 1 range(s) and 8 utterance(s) for 8 sentences
   PASS 4: the read of the document ran to its end — the toolbar's Read came back
   PASS 4: one press read the whole document (its own range) — the range: [(0, 141)], the document is 141 chars
   PASS 4: the read speaks the document's own sentences, in order, whole — 8 spoken of 8
   PASS 4: the read of the document completed without exhausting memory (SC-002) — 0 OOM lines
   PASS 4: the imported content's page offers the video tab — it draws 'Video'
   PASS 4: the imported content offers the render (SC-001) — the dialog offers Start
   PASS 4: the render's own schedule counts the document's sentences (SC-001) — plan: (0, [], 8), the document holds 8 sentences
   PASS 4: the render wrote its video and reported frames (SC-001) — report: ('/data/user/0/com.example.klhu/cache/klhu_video.mp4', 37800, 1745884, 1134)
   PASS 4: every render slot is one of the document's own sentences — 8 slots, 8 sentences

21/21 checks passed
```

The check named "the document's staged copy is burned once its bytes are read" is the reader's own rule for SC-003
(2026-10-26: *内存副本只用于阅读，读完即焚*). It is red on the previous build and green on this one: the 16:23 run printed
two cache copies of the document left behind, one per pick (`cache/<uuid>/klhu025_import.txt`). The unit half is
`test/document_picker_test.dart` — a staged copy inside the cache root is deleted, a file the reader owns is not, an
empty or already-gone path is answered without throwing, and a sibling directory whose name merely starts with the
cache root's is not treated as the cache.

The fixture carries a run-unique sentence (`第<MMDD-HHMMSS>次文档输入走查。`), so "the document's text reached the page /
the store" cannot be answered by the content an earlier run left open — the app's page and the store both have to show
*this* run's line for the check to pass.

`/tmp/klhu_out/row4_run2.log` holds the run above; it is **ephemeral** (a reboot clears it). The receipts quoted here are
that run's own lines; re-cutting them means re-running the row.

## The structural row (T007)

```
flutter analyze                     → No issues found! (ran in 1.6s)
flutter test --concurrency=2        → 912 tests, All tests passed!
   the suite without this feature's two files → 904  (files moved aside, re-run, restored)
   → this feature adds 8 cases (4 in test/document_input_test.dart, 4 in test/document_picker_test.dart);
     the tree it was built on carried 904, not the 901 tasks.md assumed
ARB keys (json key count)           → app_en 154  app_es 140  app_zh 140  app_zh_Hans 140
   the four import keys (importDocumentButton, unsupportedDocumentMessage, emptyDocumentMessage,
   documentImportFailedMessage) are in all four files
spec_consistency.py                 → no divergence; fenced blocks kept in no more than one artifact
check_tasks_format.py               → OK: format, sequencing and spec-id coverage check out (9 tasks, 9 done, 1 [P])
check_row_coverage.py               → 7 ids defined | 7 rows claim 7 | no row claims: none | table cites 7
check_quickstart_coverage.py        → 4 FR + 3 SC defined | 4 rows ([unit] 3, [device] 1) | unclaimed: none
task_id_audit.py                    → 9 tasks, 9 done, 1 [P]
```

## Findings the reviewer must weigh

### F1 — the picked file WAS copied by the plugin into the app's cache — fixed the same day (SC-003)

The app's own store root (`/data/user/0/com.example.klhu/app_flutter`) holds **no** copy of the document — the content
that landed is the extracted text (141 chars, byte-equal to the fixture), which is what FR-003 and SC-003 ask for. But
`file_selector`'s Android side copies the picked `content://` file into the app's cache before `readAsBytes()` can see
it, and never deletes it:

```
/data/data/com.example.klhu/cache/d9d97be5-…/klhu025_import.txt
/data/data/com.example.klhu/cache/432143d9-…/klhu025_import.txt      (one per pick; two picks so far)
```

So the "no local copy" rule was not met on the 15:35:20 build: on a big EPUB the copy is the whole file on the phone's
internal storage, and it was never deleted.

**Fixed on the reader's own reading of SC-003** (2026-10-26: *内存副本只用于阅读，读完即焚* — the in-memory copy is for
reading and is burned after it): `lib/platform/document_picker.dart` reads the bytes first and then deletes the
platform's staged copy through `burnCachedCopy(path, {cacheRoot})`, which deletes **only** a path inside the app's own
cache directory (the plugin's `{cacheDir}/{uuid}/{name}`) and refuses anything else — deleting a path the reader owns
would be data loss, not cleanup. Row 4 gained the check *"the document's staged copy is burned once its bytes are read
(SC-003)"*, red on the 16:23 run (two leftovers printed) and green on the 16:51 build; the unit half is
`test/document_picker_test.dart` (4 cases, including "a file the reader owns is never deleted" and a sibling directory
whose name merely starts with the cache root's).

What remains true and is worth stating: for the moments between the pick and the read, the plugin's copy does exist on
disk (that is the plugin's own design — the app cannot read a `content://` pick without it), so the honest claim is
"nothing survives the read", not "nothing is ever written". FR-003 and SC-003 were re-worded to say exactly that.

### F2 — a picture-less render crashed the shared parser (driver fix, not a device finding)

`klhu render pictures=0 ranges= sentences=8` — with nothing assigned, the ranges field is empty, and 020's
`render_plan()` split `''` into one token with no `..`, raising `ValueError` inside the driver. Fixed in
`specs/020-sentence-pictures/scripts/klhu_walk_assignment.py` (`tokens = group.split(",") if group else []`). The
change is inert for 020's own rows: they all assign pictures, and a non-empty `ranges=` takes the identical path —
the added branch is reachable only when the field is empty, which no 020 fixture produces.

### F3 — "expected 7 ranges, got 1" was the ROW's expectation, never the app

The earlier pass recorded this as a walk-script scope problem and inferred "the segmenter treats the entire text as one
unit when seeded". Both halves were wrong. Measured on the tree today: one `Continue Read` press reads the whole
content from offset 0 and logs **one** `klhu read range: 0..141`, plus **one `klhu speak` line per sentence (8)**. The
range line is per press; the utterance lines are per sentence. The old row asserted `len(ranges) == sentences`, which no
build could satisfy. The segmenter was never involved.

### F4 — the record's own counts were wrong

`app_en.arb` carries **154** keys, not the 206 this file claimed; the other three carry 140 each (as recorded). And
tasks.md's "the tree's own count is 901 tests" was stale — the tree without this feature runs **904** (measured by
moving the new test file aside), 908 with it.

## What is owed (each one is a decision, not a chore)

1. **FR-001/FR-003 for PDF, DOC, DOCX and EPUB.** `extractText()` returns `''` for all four; the reader can pick one,
   and the app then says *No text could be extracted from this document.* So the accepted-types list is a promise the
   extraction does not keep. Either implement the four readers (platform facilities; EPUB needs an unzip + XHTML text
   pass, DOC/DOCX need OOXML/Word text extraction, PDF needs a text layer or OCR) or amend FR-001 to a TXT-first cut
   with the rest as their own feature. No row covers these kinds today — row 4 drives TXT only.
2. **Q3's OCR.** `requiresOcr()` is a predicate with a test and no caller. Row 3 of the quickstart ("OCR yields the
   text") is `NOT WALKED` and cannot be walked until there is an OCR implementation; the spec's edge case ("a document
   with no extractable text is read through the added OCR functions") is unimplemented.
3. **FR-002 in the read pipeline.** `documentSegments()` is unit-tested and has **no caller in `lib/`** (grep: only its
   own definition and the test). The read therefore still walks whatever text it is handed, whole. SC-002's device half
   is proven for a 141-char document without memory pressure — it says nothing yet about a document large enough to
   need paging. Wiring it means a paged read in `reading_view`/`reader_service`, which is its own stage.
4. **FR-004's deletability, on device.** The imported content is loadable, savable, readable and renderable (row 4); it
   is deletable only in the sense that the store's delete path is unchanged. No row drives the reader's own delete on an
   imported content.
