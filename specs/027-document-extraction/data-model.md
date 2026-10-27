# Data model: document extraction

**Feature**: `027-document-extraction` | **Plan**: [plan.md](./plan.md) | **Spec**: [spec.md](./spec.md)

Everything here is derived or, where stored, already inside the content store's own contract (008). Nothing new is
persisted for the import itself — the picked document is not stored, and the reading content the import produces is
an ordinary content.

## §1 `DocumentInput` — the picked document, of a deferred kind

| field | meaning |
|---|---|
| source | the platform's file handle the pick returned (path/URI) — never stored by the app |
| name | the document's own file name |
| size | bytes |
| kind | one of the deferred kinds: `pdf`, `doc`, `docx`, `epub` |

## §2 `ImportedContent` — the reading content an import produces

| field | meaning |
|---|---|
| text | the extracted text (platform extraction, or OCR where the text layer is absent — Q2) |
| language | the reading language the paragraph-level detection assigns (spec 003) |
| origin | `user` — it lands in the content library's list like hand-written content (FR-004) |

## §3 The segment the read walks — pages, else bounded segments (Q1)

The memory unit of SC-002, taken up from 025's TXT-first cut. An import of a document that carries pages reads them
**page by page**; an import whose extraction yields no page structure reads **bounded segments of the extracted
text**. The empty/no-text case reads nothing.

## §4 What is *not* stored

The picked document, the extraction artifacts and the OCR output are not persisted by the import; the content that
enters the pipeline is the text — and the content that enters the library is the ordinary content of §2.
