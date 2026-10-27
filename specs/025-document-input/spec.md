# Feature Specification: Document input

**Feature Branch**: `025-document-input`

**Created**: 2026-10-25

**Status**: Draft

**Input**: The reader's wish list (`text.txt`), item 025, quoted verbatim — substring-checked line by
line against the file (four lines, none reflowed, none dropped):

> 025. as a kalahoo reading user, I like to input document file to generate reading content.
>     document file type: pdf, doc, docx, txt and popular e-book formats.
>     should support page by page reading for large file to avoid memory issue.
>     should support direct document file reading to avoid creating local file for kalahoo app.

## What the tree already carries, and the gap the item names

The reading pipeline already speaks whatever text it is handed. A reader writes or edits a content, saves it
through the content library (`lib/services/content_store.dart`, spec 008), and the segmenter cuts it into
sentences (`lib/segmenter.dart`); the reader hands the sentences to the engine with the paragraph's language and
voice, tracking the offsets the highlight follows (`lib/reader_service.dart`); the renderer paints frames to the
engine's measured audio (`lib/video_renderer.dart`). Nothing downstream of the text is missing — the item is not
about the speaking, the painting or the storing, it is about **getting a document file into that pipeline**.

The item's three lines are therefore three seams on an existing path:

1. **Input** — which document file, and how the reader gives it to the app.
2. **Page-by-page** — how the app reads a large document without holding it whole in memory.
3. **Direct** — whether the picked file is staged as a local file or read straight through.

## Clarifications

### The reader's answers — asked at this stage, answered by the reader's own words (2026-10-25)

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | What does "page by page" mean for the reading content? | **Use the phone's original document's page if possible; otherwise use bounded segments of the extracted text.** | reading the whole extracted text as one unbounded content — the memory problem the item itself exists to remove |
| **Q2** | Which "popular e-book formats" are in the first cut? | **EPUB format, for now.** | any other e-book format this feature — a second extraction to maintain before the reader asks for it |
| **Q3** | What of a document whose text cannot be extracted? | **Add OCR functions for this spec and the next AI support.** | refusing such documents outright, with OCR left to a later feature |
| **Q4** (2026-10-26) | What does the item's third line — "direct document file reading to avoid creating local file" — mean, precisely? | **"不用存 Kalahoo 本地文件。内存副本只用于阅读，读完即焚。"** — no KalaHoo file is kept: the only copy while reading is the one in memory, and it is not kept after the read. | keeping the platform's staged copy as the content's source, or keeping the picked file for a later re-read |

Q4 was asked at the walk, when the measure showed `file_selector` leaving its own copy of every pick in the app's cache;
FR-003 and SC-003 were re-worded against it in the same pass (nothing else in the spec moved).

The answers were put as they were received and bound here in the reader's own words; each keeps the item's own
wording where the answer was conditional (Q1's "if possible").

## User Scenarios & Testing

### User Story 1 - Feed a document, get reading content (Priority: P1)

As a KalaHoo Reading user, I want to input a document file and have it become reading content, so I can read it
aloud without typing or pasting it.

**Why this priority**: the item is an input wish; without it there is no content to read, and every later
surface (the library, the read, the video) already exists to serve it.

**Independent Test**: an import of a supported document yields reading content the reader can open, read, save,
edit and turn into a video — the same content behaviour hand-written text already has.

**Acceptance Scenarios**:

1. **Given** a document file of a supported type, **When** the reader inputs it, **Then** it becomes reading
   content in the library.
2. **Given** imported content, **When** the reader reads it, **Then** the paragraphs are spoken with the right
   voices and the highlight follows the read.
3. **Given** imported content, **When** the reader saves, edits or deletes it, **Then** it behaves like any
   other content.

### User Story 2 - Read large documents page by page (Priority: P2)

As a KalaHoo Reading user, I want large documents to be read page by page, so no document is held whole in
memory.

**Why this priority**: it is a hard constraint of the item, but it delivers value only once a document exists to
read.

**Independent Test**: a large document is read across page-sized units and the read completes without memory
exhaustion.

**Acceptance Scenarios**:

1. **Given** a large document, **When** it is read, **Then** no more than one page's text is held in memory at a
   time.

## Edge Cases

- A file outside the supported set is refused, and nothing is stored.
- A document with no extractable text is read through the added OCR functions (the Q3 answer), and never
  half-reads.
- A large document is read page by page; a final partial page is read like any other.
- A document in a mixed language is read like any other content (per-paragraph language detection, spec 003).

## Requirements

### Functional Requirements

- **FR-001**: The app MUST accept a document file as reading-content input; the accepted types are the
  reader's own list — PDF, DOC, DOCX, TXT, and EPUB (the first-cut e-book format).
- **FR-002**: The app MUST read an accepted document page by page — using the phone's original document's page
  where the document has one, and bounded segments of the extracted text otherwise — holding no more than one
  page's text in memory at a time.
- **FR-003**: The app MUST read the picked document directly through the platform's file access rather than
  keeping a local copy of it: the bytes are read into memory, the temporary copy the platform stages for that read is
  deleted as soon as they are in memory, and nothing of the document survives the read (Q4). The extracted
  text then enters the content pipeline, and where the document's text cannot be extracted the app adds the OCR
  functions this spec carries (the Q3 answer, also carried into the next AI support).
- **FR-004**: The reading content an import produces MUST be an ordinary content: it appears in the library
  list, is loadable, savable, editable and deletable, and is read and rendered exactly like hand-written content.

### Key Entities

- **DocumentInput**: a picked document file — source, name, size, kind.
- **ImportedContent**: the reading content generated from a document — its text and language.

## Success Criteria

### Measurable Outcomes

- **SC-001**: An import of a supported document yields reading content the read pipeline speaks — the reader
  can read the imported document aloud, and it behaves like any other content in the library. **Receipt** (row 4,
  device, 2026-10-26, build 15:35:20): a real `.txt` imported through the app's own import tab and DocumentsUI's own
  roots — the page painted the document's 140 chars, the store gained exactly one content (`origin: user`,
  `language: zh-Hans`), its stored text was 141 chars byte-equal to the file, one `Continue Read` press logged
  `klhu read range: 0..141` and 8 `klhu speak` lines in the document's own sentence order, and the render reported
  `sentences=8 … frames=1135` with 8 slots. **Limit**: TXT only — PDF/DOC/DOCX/EPUB extraction does not exist yet,
  and no row drives deleting an imported content (breakpoint.md § What is owed 1 and 4).
- **SC-002**: A large document is read page by page — the phone's original pages where they exist, bounded
  segments of the extracted text otherwise — and the read completes without memory exhaustion. **Receipt**:
  `documentSegments()` answers Q1 with bounded segments (unit table), and row 4's read of a 141-char document ran to
  its end with `0` OOM lines. **Limit**: the read pipeline does not call `documentSegments()` yet — it has no caller
  in `lib/` — so page-by-page reading is not implemented on any path the reader can reach, and no document large
  enough to need paging has been read (breakpoint.md § What is owed 3).
- **SC-003**: No local copy of the picked document survives the read: the bytes are held in memory for reading, the
  temporary copy the platform stages for that read is deleted as soon as they are in memory, and the content that
  enters the library is the extracted text (Q4). **Receipt** (row 4, re-walked on the 16:51 build after the burn
  landed): the app's own store root (`/data/user/0/com.example.klhu/app_flutter`) held 9 files, none of them the
  picked document; the app's cache held **no** copy of it after the import; and the content that landed is the
  extracted text byte for byte. On the previous build the same check printed two leftover copies, one per pick.
  **Limit**: between the pick and the read the platform's own staged copy does exist on disk — the plugin cannot read
  a `content://` pick without it — so the claim is "nothing survives the read", not "nothing is ever written"
  (breakpoint.md F1).

## Assumptions

- **A1**: The supported-type list is the reader's own wording; the first-cut set is open (Q2).
- **A2**: Text extraction for PDF/DOCX/epub uses the platform's own facilities, and OCR functions are added for
  a document whose text cannot be extracted (the Q3 answer — carried here and into the next AI support); the
  content they read then enters the content pipeline like any other extracted text.
- **A3**: Imported content is language-detected per paragraph like any other content (spec 003).

## Out of scope

- Translation (item 016 of the wish list); AI access (item 026 of the wish list); server-side storage.

## What this feature does not supersede

Nothing. It adds an input before the content pipeline; no earlier requirement is withdrawn or re-worded, and the
library, the read and the renderer keep their own contracts (008, 003, 012).
