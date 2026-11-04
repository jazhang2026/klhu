# Feature Specification: AI Skills for Content Generation

**Feature Branch**: `030-ai-skills-for-content-generation`

**Created**: 2026-11-03

**Status**: Draft

**Input**: the reader's wish list (`text.txt`), item 030 — create skill sets so the AI can help generate content that matches KalaHoo Reading's format (role tags `{name}`, comment tags `[comment]`, scene tags `[scene]`, etc.), with automatic stripping of the AI's conversational header/footer.

## What this feature does

Adds **AI skills** — pre-built prompt templates — to the AI prompt dialog, so the reader can turn a simple request into properly formatted reading content in one tap.

- The AI prompt dialog (spec 029) gains a **skill picker** above the prompt field.
- Each skill carries a template with `{{variable}}` placeholders; picking a skill fills the prompt field with the rendered template.
- Three shipped skills: **Story** (narrative text), **Dialogue** (multi-role conversation with `{role}` tags), **Lesson** (bilingual text with `[comment]` translation tags).
- After the AI returns text, a **post-processor** strips conversational header/footer so only the reading content remains.
- The reader can **save the current prompt as a custom skill** for reuse.

## Clarifications

### The reader's answers

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | What formats must AI-generated content obey? | **Role tags** `{name}` or `{角色名称}` at paragraph heads; **comment tags** `[comment]` / `[注]` / `[註]` / `[nota]`; **scene tags** `[scene]` / `[场景]`; **head tags** `#` / `##`. The AI output must use these so the existing dialogue/comment/head-tag parsers consume it without change. | generating plain prose the reader must reformat by hand. |
| **Q2** | How does the reader choose a skill? | **Inside the existing AI prompt dialog**, above the prompt text field: a skill chip/picker row. Tapping a skill renders its template into the prompt field; the reader can then edit before submitting. | a separate screen or a side panel. |
| **Q3** | What happens to the AI's conversational filler? | A **post-processor** strips the first 1–3 lines if they look like filler ("Sure!", "Here's your story…", "Let me know if you need anything!"). The remaining text is what lands as content. If the processor can't identify a clean split, the full response is passed through and the reader edits manually. | sending the raw AI response straight to the content area. |
| **Q4** | Can the reader create their own skills? | Yes — a **"Save as skill"** button in the prompt dialog lets the reader persist the current prompt (with its template variables filled in) as a named custom skill, stored in SharedPreferences alongside provider config. | skills being read-only presets. |
| **Q5** | What generation types do skills support? | **Text only** for now. Image and video skills are future work (Q6). | no type restriction at the data model level — the `AISKill.defaultType` field can be extended later. |

## User Scenarios & Testing

### User Story 1 — Generate a dialogue story from a simple request (Priority: P1)

As a KalaHoo Reading user, I want to pick the "Dialogue" skill, type a short request like "a conversation between a teacher and student about weather", and get back content formatted with `{teacher}：...` and `{student}：...` paragraphs that I can read immediately.

**Why this priority**: This is the core value — turning a one-line idea into properly formatted multi-role content without manual tag editing.

**Independent Test**: pick Dialogue skill → enter a simple request → submit → the returned text contains `{role}：` paragraphs → the content reads correctly with role-assigned voices.

### User Story 2 — Generate bilingual lesson content (Priority: P2)

As a KalaHoo Reading user, I want to pick the "Lesson" skill, enter a topic like "shopping at the market in Spanish", and get back text where the Spanish sentences are read by the Spanish voice and the English translations are hidden behind `[comment]` tags.

**Why this priority**: Bilingual content is a common teaching use case; the `[comment]` tag is already supported by the reader.

**Independent Test**: pick Lesson skill → enter topic → submit → returned text contains `[comment]English translation` after each Spanish sentence → the reader hears only Spanish, sees both languages.

### User Story 3 — Save and reuse a custom skill (Priority: P3)

As a KalaHoo Reading user, I want to craft a prompt I like, save it as a skill called "My Fable Style", and reuse it next time without retyping.

**Why this priority**: Power users will develop their own prompt patterns; saving them avoids repetition.

**Independent Test**: edit the prompt field → tap "Save as skill" → enter a name → the skill appears in the picker → tapping it re-fills the prompt field with the saved text.

## Requirements

### Functional Requirements

- **FR-001**: The AI prompt dialog MUST show a skill picker row above the prompt text field when at least one skill is available.
- **FR-002**: The app MUST ship three built-in skills: **Story** (narrative), **Dialogue** (multi-role conversation with `{role}` tags), **Lesson** (bilingual with `[comment]` tags).
- **FR-003**: Tapping a skill MUST render its template into the prompt text field, replacing any existing text, with `{{variable}}` placeholders filled from the dialog's current context (e.g. the selected text type).
- **FR-004**: The app MUST run a post-processor on the AI's text response before it lands as content: strip conversational header/footer lines, keeping only the reading-content portion.
- **FR-005**: The prompt dialog MUST offer a "Save as skill" action that persists the current prompt text (with placeholders resolved) as a named custom skill in SharedPreferences.
- **FR-006**: Custom skills MUST appear in the skill picker alongside built-in skills, indistinguishable in layout but labelled with a "custom" badge.
- **FR-007**: The reader MUST be able to delete a custom skill from the picker (long-press or swipe, same UX as provider deletion in Settings).
- **FR-008**: Skills MUST only support `AIPromptType.text` — selecting an image or video type while a skill is active shows a disabled state or a brief warning.

## Edge Cases

- **No skills configured**: the skill picker row is hidden; the dialog looks identical to spec 029's baseline.
- **Post-processor can't find a clean split**: the full AI response is passed through; the reader edits manually.
- **Skill template has unfilled placeholders**: the placeholders remain visible (`{{topic}}`) in the prompt field; the reader fills them before submitting.
- **AI returns non-text content** (an image URL or video URL) when a text skill was active: the existing image/video preview path handles it — the post-processor only runs on text responses.
- **Saving a skill with the same name as a built-in**: the custom skill overwrites the built-in entry under that name (built-in names are just defaults, not locked).
