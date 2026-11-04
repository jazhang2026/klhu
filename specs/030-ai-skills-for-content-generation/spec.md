# Feature Specification: AI Skills for Content Generation

**Feature Branch**: `030-ai-skills-for-content-generation`

**Created**: 2026-11-03

**Status**: CLOSED

**Input**: the reader's wish list (`text.txt`), item 030 — create skill sets so the AI can help generate content that matches KalaHoo Reading's format (role tags `{name}`, comment tags `[comment]`, scene tags `[scene]`, etc.), with automatic stripping of the AI's conversational header/footer.

## What this feature does

Adds **AI skills** — pre-built prompt templates — to the AI prompt dialog, so the reader can turn a simple request into properly formatted reading content in one tap.

- The AI prompt dialog (spec 029) gains a **skill dropdown** below the provider dropdown (only shown when `AIPromptType.text` is selected; spec FR-008).
- Each skill carries a template with `{{variable}}` placeholders; picking a skill fills the prompt field with the rendered template.
- Three shipped skills: **Story** (narrative text), **Dialogue** (multi-role conversation with `{role}` tags), **Lesson** (bilingual text with `[comment]` translation tags).
- After the AI returns text, a **post-processor** strips conversational header/footer so only the reading content remains.
- All labels in the AI provider config screen and the prompt dialog are fully internationalized (i18n) across English, Chinese, and Spanish.

## Clarifications

### The reader's answers

| # | the question as put | the answer in force | the alternative it refuses |
|---|---|---|---|
| **Q1** | What formats must AI-generated content obey? | **Role tags** `{name}` or `{角色名称}` at paragraph heads; **comment tags** `[comment]` / `[注]` / `[註]` / `[nota]`; **scene tags** `[scene]` / `[场景]`; **head tags** `#` / `##`. The AI output must use these so the existing dialogue/comment/head-tag parsers consume it without change. | generating plain prose the reader must reformat by hand. |
| **Q2** | How does the reader choose a skill? | **A dropdown below the provider dropdown** in the AI prompt dialog, only visible when `AIPromptType.text` is selected. Tapping a skill renders its template into the prompt field; the reader can then edit before submitting. | a chip row above the prompt field, or a separate screen. |
| **Q3** | What happens to the AI's conversational filler? | A **post-processor** strips the first 1–3 lines if they look like filler ("Sure!", "Here's your story…", "Let me know if you need anything!"). The remaining text is what lands as content. If the processor can't identify a clean split, the full response is passed through and the reader edits manually. | sending the raw AI response straight to the content area. |
| **Q4** | What generation types do skills support? | **Text only** for now. Image and video skills are future work (Q5). When `image` or `video` is selected, the skill dropdown is hidden (FR-008). | no type restriction at the data model level — the `AISkill.defaultType` field can be extended later. |
| **Q5** | What about i18n? | **All AI-related strings are fully localized** — the provider config screen, the prompt dialog, the image preview, and the progress dialog all use `AppLocalizations` across English, Chinese (Simplified + Traditional), and Spanish. | hard-coding English strings in the AI screens. |

## User Scenarios & Testing

### User Story 1 — Generate a dialogue story from a simple request (Priority: P1)

As a KalaHoo Reading user, I want to pick the "Dialogue" skill from the dropdown (after selecting Text type), type a short request like "a conversation between a teacher and student about weather", and get back content formatted with `{teacher}：...` and `{student}：...` paragraphs that I can read immediately.

**Why this priority**: This is the core value — turning a one-line idea into properly formatted multi-role content without manual tag editing.

**Independent Test**: select Text type → pick Dialogue skill from dropdown → submit → the returned text contains `{role}：` paragraphs → the content reads correctly with role-assigned voices.

### User Story 2 — Generate bilingual lesson content (Priority: P2)

As a KalaHoo Reading user, I want to pick the "Lesson" skill, enter a topic like "shopping at the market in Spanish", and get back text where the Spanish sentences are read by the Spanish voice and the English translations are hidden behind `[comment]` tags.

**Why this priority**: Bilingual content is a common teaching use case; the `[comment]` tag is already supported by the reader.

**Independent Test**: select Text type → pick Lesson skill → submit → returned text contains `[comment]English translation[/comment]` after each Spanish sentence → the reader hears only Spanish, sees both languages.

### User Story 3 — Save and reuse a custom skill (Priority: P3)

Not yet implemented. The data model (`AISkillStore`) supports `upsert` and `delete` for custom skills; the UI entry point (save button in the dialog) is planned but not yet wired up.

## Requirements

### Functional Requirements

- **FR-001**: The AI prompt dialog MUST show a skill dropdown below the provider dropdown when the generation type is `text` and at least one skill is available.
- **FR-002**: The app MUST ship three built-in skills: **Story** (narrative), **Dialogue** (multi-role conversation with `{role}` tags), **Lesson** (bilingual with `[comment]` tags).
- **FR-003**: Tapping a skill MUST render its template into the prompt text field, replacing any existing text, with `{{variable}}` placeholders left for the reader to fill.
- **FR-004**: The app MUST run a post-processor on the AI's text response before it lands as content: strip conversational header/footer lines, keeping only the reading-content portion.
- **FR-005**: Custom skills MUST be stored in SharedPreferences alongside built-in skills, under the key `ai_skills`.
- **FR-006**: The reader MUST be able to delete a custom skill via `SkillStore.delete()`.
- **FR-007**: Built-in skills MUST be protected from deletion — `SkillStore.delete()` returns `false` for built-in IDs.
- **FR-008**: Skills MUST only appear when `AIPromptType.text` is selected; the dropdown is hidden for `image` and `video` types.
- **FR-009**: All strings in the AI provider config screen and the AI prompt dialog MUST be localized through `AppLocalizations`.

## Edge Cases

- **No skills configured**: the skill dropdown is hidden; the dialog looks identical to spec 029's baseline.
- **Post-processor can't find a clean split**: the full AI response is passed through; the reader edits manually.
- **Skill template has unfilled placeholders**: the placeholders remain visible (`{{topic}}`) in the prompt field; the reader fills them before submitting.
- **AI returns non-text content** (an image URL or video URL) when a text skill was active: the existing image/video preview path handles it — the post-processor only runs on text responses.
- **Switching generation type**: when the reader switches from `text` to `image` or `video`, the skill selection is cleared automatically.
