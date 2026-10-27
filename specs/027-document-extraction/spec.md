# Feature Specification: Document extraction

**Feature Branch**: `027-document-extraction`

**Created**: 2026-10-27

**Status**: Draft

**Input**: the reader's wish list (`text.txt`), item 025's later half — the kinds the **TXT-first cut** (2026-10-27)
amended 025's FR-001 to set aside: PDF, DOC, DOCX and EPUB as reading-content input, with the extraction the item
always asked for.

## What this feature does

The document-input feature closed with an accepted set of **TXT** — the first-cut type its own extraction reads —
and deferred the PDF, DOC, DOCX and EPUB kinds to later features. This feature takes the reader's open list up where
that cut stopped: a picked document of a deferred kind is accepted, its text is extracted through the platform's own
facilities, and the extracted text becomes reading content the library, the read and the renderer already serve.

## Clarifications

### The reader's answers — asked at this stage, answered by the reader's own words (2026-10-27)

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | How is a PDF, DOC, DOCX or EPUB document read — page by page? | **Use the phone's original document's page if possible; otherwise use bounded segments of the extracted text.** | reading the whole extracted text as one unbounded content — the memory problem the original item exists to remove |
| **Q2** | What of a document whose text cannot be extracted? | **Add OCR functions for this feature and the next AI support.** | refusing such documents outright, with OCR left to a later feature |
| **Q3** | What does the reader's third line mean, again? | **"不用存 Kalahoo 本地文件。内存副本只用于阅读，读完即焚。"** | keeping a local copy of the picked document |

## User Scenarios & Testing

### User Story 1 - Feed a deferred-kind document, get reading content (Priority: P1)

As a KalaHoo Reading user, I want to input a PDF, DOC, DOCX or EPUB document and have it become reading content, so I
can read it aloud without typing or pasting it.

**Why this priority**: the deferred half of the input wish — without it there is no content to read, and every later
surface (the library, the read, the video) already exists to serve it.

**Independent Test**: an import of a deferred-kind document yields reading content the reader can open, read, save,
edit and turn into a video — the same content behaviour hand-written text already has.

**Acceptance Scenarios**:

1. **Given** a document file of a deferred kind, **When** the reader inputs it, **Then** it becomes reading content in
   the library.
2. **Given** imported content, **When** the reader reads it, **Then** the paragraphs are spoken with the right voices
   and the highlight follows the read.
3. **Given** imported content, **When** the reader saves, edits or deletes it, **Then** it behaves like any other
   content.

### User Story 2 - Read large extracted documents page by page (Priority: P2)

As a KalaHoo Reading user, I want large documents to be read page by page, so no document is held whole in memory.

**Why this priority**: it is a hard constraint of the original item, but it delivers value only once a document of a
deferred kind exists to read.

**Independent Test**: a large document is read across page-sized units and the read completes without memory
exhaustion.

**Acceptance Scenarios**:

1. **Given** a large document, **When** it is read, **Then** no more than one page's text is held in memory at a time.

## Edge Cases

- A file outside the deferred set is refused, and nothing is stored.
- A document with no extractable text is read through the added OCR functions (the Q2 answer), and never half-reads.
- A large document is read page by page; a final partial page is read like any other.
- A document in a mixed language is read like any other content (per-paragraph language detection, spec 003).

## Requirements

### Functional Requirements

- **FR-001**: The app MUST accept a document file of a deferred kind (PDF, DOC, DOCX, EPUB) as reading-content input,
  and extract its text through the platform's own facilities.
- **FR-002**: The app MUST read an accepted document page by page — using the phone's original document's page where
  the document has one, and bounded segments of the extracted text otherwise — holding no more than one page's text in
  memory at a time.
- **FR-003**: The app MUST read the picked document directly through the platform's file access rather than keeping a
  local copy of it: the bytes are read into memory, the temporary copy the platform stages for that read is deleted as
  soon as they are in memory, and nothing of the document survives the read (Q3). The extracted text then enters the
  content pipeline, and where the document's text cannot be extracted the app adds the OCR functions this spec carries
  (the Q2 answer).
- **FR-004**: The reading content an import produces MUST be an ordinary content: it appears in the library list, is
  loadable, savable, editable and deletable, and is read and rendered exactly like hand-written content.

### Key Entities

- **DocumentInput**: a picked document file — source, name, size, kind.
- **ImportedContent**: the reading content generated from a document — its text and language.

## Success Criteria

### Measurable Outcomes

- **SC-001**: An import of a deferred-kind document yields reading content the read pipeline speaks — the reader can
  read the imported document aloud, and it behaves like any other content in the library.
- **SC-002**: A large document is read page by page — the phone's original pages where they exist, bounded segments of
  the extracted text otherwise — and the read completes without memory exhaustion.
- **SC-003**: No local copy of the picked document survives the read: the bytes are held in memory for reading, the
  temporary copy the platform stages for that read is deleted as soon as they are in memory, and the content that enters
  the library is the extracted text.

## Assumptions

- **A1**: The deferred kinds are the reader's own list — PDF, DOC, DOCX and EPUB — and the first-cut set is open.
- **A2**: Text extraction for PDF/DOCX/epub uses the platform's own facilities, and OCR functions are added for a
  document whose text cannot be extracted (the Q2 answer — carried here and into the next AI support).
- **A3**: Imported content is language-detected per paragraph like any other content (spec 003).

## Out of scope

- Translation (item 016 of the wish list); AI access (item 026 of the wish list); server-side storage.

## What this feature does not supersede

Nothing. It takes over the deferred half of 025's document input; no earlier requirement is withdrawn, and the library,
the read and the renderer keep their own contracts (008, 003, 012).
