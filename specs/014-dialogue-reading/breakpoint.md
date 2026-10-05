# Device validation: Dialogue Reading (014)

**Feature**: `014-dialogue-reading` | **Date**: 2026-10-03 (in progress — rows 23 onward are walked as their
tasks land)
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Tasks**: [tasks.md](./tasks.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400), package `com.example.klhu` |
| Build | the row's own `flutter build apk --debug` + `adb install -r`, so the device ran the code the suite runs; `flutter analyze` clean; `flutter test --concurrency=2` → **529 passing, 0 failing** (2026-10-03, before row 23) |
| Driver | `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py` — imports 012's `klhu_walk_video.py` for the mechanics (one string per `adb shell`, `uiautomator dump` reads, `tap`, `check`); rows implemented as they are walked |
| Fixture | `specs/014-dialogue-reading/scripts/klhu_dialogue_fixture.txt` — the reader's own four roles, pushed into the app's library by the driver |
| App locale | the reference AVD draws the app in Chinese, so every label the driver taps is matched in both languages (`app_zh_Hans.arb` / `app_en.arb`) |
| Engine | Google TTS; `logcat` carries the app's own evidence lines — `klhu speak`, `klhu roles`, `klhu read range` |

Rows are **WALKED — PASS** (device PASS plus the lines that prove it), **[unit]** (the Dart test that carries
it), **[structural]**, **PENDING** (not yet runnable), or **UNVERIFIED WITH REASON**.

**State of this file**: rows **23** and **24** are walked and pass (10/10 and 13/13 checks). Rows **25, 26, 27, 28, 33** are
**PENDING** — each is walked in the pass that implements its dispatch in the driver, which is this file's
next entries. Nothing here is inferred: every claim below is a line the driver read back.

---

## Row 23 — a four-role dialogue read on the device

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 23` → **10/10 checks passed**
(exit 0).

**What it did, through the app's own controls**: dropped the app's stored settings (`shared_prefs`), pushed
the fixture into the library and reopened the app on it, tapped `文字类型` → `多人对话` → `完成`, cleared
logcat, tapped `继续朗读`, and waited for the read's own `klhu speak` lines rather than a sleep.

**The lines it read** (logcat, `I/flutter`, 2026-10-03 19:39:09.952, one session):

```
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)
klhu read range: 0..101
klhu speak p0 s0 role=旁白 voice=cmn-cn-x-ccc-local "今天天气很好，适合出去走走。"
klhu speak p1 s0 role=阿明 voice=cmn-cn-x-ccd-local "今日个天气真系唔错啊，行下公园好舒服。"
klhu speak p2 s0 role=May voice=cmn-cn-x-cce-local "系啊，太阳晒住，风又凉爽。"
klhu speak p2 s1 role=May voice=cmn-cn-x-cce-local "真系适合周末。"
klhu speak p3 s0 role=阿芳 voice=cmn-cn-x-ssa-local "我好少黎呢个公园，原来呢度风景咁靓。"
```

**Checks** (all PASS, with the driver's own detail):

| Check | Detail |
|---|---|
| the fixture reached the device, whole | 101 chars read back with `run-as cat`, byte-identical to the file |
| the app stored the type and nothing else (FR-001) | `content_roles[dialogue_fixture] = {'type': 'dialogue'}` read out of `FlutterSharedPreferences.xml` |
| every sentence of the fixture reached the engine | 5 `klhu speak` lines |
| no spoken text carries a tag (FR-005) | the five quoted texts, braces and all, are absent |
| no spoken text carries a role name (FR-005) | 旁白/阿明/May/阿芳 appear in no spoken text |
| one line per sentence, in the text's order (FR-010) | `p/s: [(0,0), (1,0), (2,0), (2,1), (3,0)]` |
| every line names its role and voice (D10) | `['旁白', '阿明', 'May', 'May', '阿芳']` |
| the two-line turn speaks as its two sentences, in one voice | May: `[(2,0,'cmn-cn-x-cce-local'), (2,1,'cmn-cn-x-cce-local')]` |
| the four roles do not share one voice (FR-015) | four distinct ids, one per role |
| the read named the whole assignment (D10) | the `klhu roles` line above |

**Proves** FR-003 (a turn is a paragraph), FR-005 (the tag is never spoken), FR-010 (a turn is read sentence
by sentence), FR-018 (each line names its role and the voice the engine was given), SC-001, SC-002.

**What this row found** (both are the app working as specified; both were surprises in the walk):

1. **A line break inside a turn is not a sentence boundary.** The fixture's first version had the reader's
   own comma at the end of May's first line (`…风又凉爽，` / `真系适合周末。`) and the app read it as **one**
   utterance — `klhu speak p2 s0 … "系啊，太阳晒住，风又凉爽， 真系适合周末。"` — which is the sentence
   rule doing its job (the log flattens the newline for one line; the engine got the newline itself). Row
   23's expectation ("that turn coming out as its two sentences") needs the sentence to end where the line
   ends, so the fixture now ends May's first line with `。`; what the multi-line *turn* proves either way is
   that one turn is one role and one voice across both lines.
2. **`朗读` (Read) is the selection read, not the whole content.** The first run tapped it with nothing
   highlighted and the page answered `请先选择要朗读的句子或段落`, reading nothing. "From the top" is
   `继续朗读` (Continue Read) — the page's `_readRange(_anchor ?? 0, length)` — which is what the driver
   taps now.

**The assignment, for the reader's eye**: 旁白→`cmn-cn-x-ccc-local` (female), 阿明→`cmn-cn-x-ccd-local`
(male), May→`cmn-cn-x-cce-local` (male), 阿芳→`cmn-cn-x-ssa-local` (female). Four distinct voices, as
FR-015 asks. **May reads in a male voice** although the reader's own example (spec.md → Input, 2) asks for
May：女声: the app assigns on distinctness and never infers a role's gender from its name (research D5 — it
may use a *recorded* gender only to keep two roles apart, and after 旁白/阿明 both genders are already in
use). Honouring "May：女声" is the reader's own act: pick May's voice (row 17's picker, FR-012) — row 25
walks that it survives a restart. This is the design, not a gap; it is called out here because the reader's
example and the app's default disagree by construction.

---

## Row 24 — the assignment against the device's own voices

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 24` → **13/13 checks passed**
(exit 0).

**What it did**: four reads of the fixture and one of a content with more roles than the device has voices —
each through the app's own screens (`文字类型` → `多人对话` → `完成`, then `继续朗读`), each windowed by the
device's own clock (`logcat -T`, not a cleared buffer) and waited on the app's own lines rather than a sleep.

**The app's own lines** (logcat `I/flutter`, 2026-10-03, one session per read):

```
# first read — no picks, and the app stored no voices (FR-014: derived, never stored)
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)

# second open of the same content — the same line, voice for voice
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)

# after the reader picked 普通话 SSA (女) for the language — 旁白 reads in it (FR-013)
voice_zh_Hans = cmn-cn-x-ssa-local||zh-CN
klhu roles 旁白→cmn-cn-x-ssa-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-ccc-local(female) 阿芳→cmn-cn-x-cce-local(male)

# 24 roles on a 15-voice pool — every role past the pool in the top-ranked voice
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)
R1→cmn-tw-x-ctc-local(female) R2→cmn-tw-x-ctd-local(male) R3→cmn-tw-x-cte-local(male) R4→yue-HK-language(female)
R5→yue-hk-x-jar-local(female) R6→yue-hk-x-yuc-local(female) R7→yue-hk-x-yud-local(male) R8→yue-hk-x-yue-local(female)
R9→yue-hk-x-yuf-local(male) R10→zh-CN-language(female) R11→zh-TW-language(female)
R12→cmn-cn-x-ccc-local(female) … R20→cmn-cn-x-ccc-local(female)
```

**Checks** (all PASS):

| Check | Detail |
|---|---|
| the read printed the whole assignment (D10) | four roles, four voices |
| every role's voice is a voice the device reports (FR-014) | all four ids are among the 472 the app logged with `klhu getVoices` |
| every voice is of its turn's own language (FR-014) | the fixture's four turns are all zh-Hans; the voices' locales read back `zh-CN ×4` |
| no role is silent and none falls back to the OS default (FR-015) | four real ids, no `os-default` |
| each of the four roles got a voice of its own (FR-015) | 4 distinct for 4 roles |
| the second role differs in recorded gender from the first (FR-015, D5) | recorded genders in order: `female, male, male, female` |
| the same content assigns the same voices on a second open (FR-014) | first = second, voice for voice |
| the picker drew the device's Chinese voices (gender beside each) | `普通话 CCE (男)`, `普通话 SSA (女)`, `普通话 CCD (男)` … |
| the pick is the reader's, stored under the language (FR-013) | `voice_zh_Hans = cmn-cn-x-ssa-local||zh-CN` |
| 旁白 reads in the voice the reader picked (FR-013) | before `cmn-cn-x-ccc-local` → after `cmn-cn-x-ssa-local` |
| the roles after it still differ (FR-015) | 旁白 `ssa`, 阿明 `ccd`, May `ccc`, 阿芳 `cce` |
| past the device's voices the sharing is visible and no role is silent (SC-004) | 24 roles on 15 distinct voices; the nine past the pool all read `cmn-cn-x-ccc-local` |
| the read reached the last role, so no role's read failed (SC-004) | 25 utterances handed to the engine, the last being R20 |

**Proves** FR-013 (a pick wins and is stored under the language), FR-014 (the assignment is derived and
stable, and every voice is a real installed voice of the turn's language), FR-015 (distinct voices, gender
only as a tie-break, sharing visible when the pool runs out), SC-003, SC-004.

**What this row found**

1. **The device's pool for zh-Hans is 15 voices, not 4.** The four the fixture's roles land on are the
   alphabetically first (`cmn-cn-x-ccc/ccd/cce/ssa`); the pool also holds three `cmn-tw`, five `yue-hk` and
   three **default-voice rows** (`yue-HK-language`, `zh-CN-language`, `zh-TW-language`). Those rows were the
   one thing that looked like a bug — the assignment reading a role in `yue-HK-language` — until the picker's
   own list showed them as `广东话默认语音 (女)` / `台湾国语默认语音 (女)`: the list the reader sees and the
   list the assignment draws from are the same list, as the design requires. **The sharing case therefore
   needed 24 roles**, not the five a first attempt used.
2. **Past the pool the assignment is deterministic, not scattered**: every role beyond the 15 reads in
   `cmn-cn-x-ccc-local` (the top-ranked candidate) rather than the pool being dealt round-robin. SC-004 asks
   for "a voice, visible sharing, no silence" and gets exactly that; the reader hears the extras in one voice.
3. **Two driver bugs the device found**, both in the evidence capture rather than the app: `logcat -c` is
   asynchronous — the first run of this row read **0** `klhu speak` lines while the app had spoken all five —
   so the rows now window the log with the device's own timestamp taken just before the tap; and
   `adb shell date +'%m-%d %H:%M:%S.000'` must be one argument, because the device's shell splits it and
   toybox answers "Max 1 argument", leaving `-T` empty.

---

## Rows still to walk

| Row | What | Why pending |
|---|---|---|
| 25 | a removal and a pick survive a restart; delete clears the entry | driver dispatch not written yet |
| 26 | switching the type mid-read keeps the reader's place | driver dispatch not written yet |
| 27 | a dialogue's video on the device | driver dispatch not written yet |
| 28 | spike S1 — the device's installed voices per language | driver dispatch not written yet (the app's own `klhu getVoices` lines are 3811 in one row-23 log, so the source is already on the wire) |
| 33 | the editor's Format press, with the reader's own hands | driver dispatch not written yet |
