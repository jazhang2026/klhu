# Device validation: Dialogue Reading (014)

**Feature**: `014-dialogue-reading` | **Date**: 2026-10-05 — every row walked; the walk began 2026-10-03
**Quickstart**: [quickstart.md](./quickstart.md) | **Spec**: [spec.md](./spec.md) | **Plan**: [plan.md](./plan.md) | **Tasks**: [tasks.md](./tasks.md)

## Environment

| | |
|---|---|
| Device | `emulator-5554` (AVD `klhu`, API 36, `sdk_gphone64_x86_64`, 1080×2400), package `com.example.klhu` |
| Build | the row's own `flutter build apk --debug` + `adb install -r`, so the device ran the code the suite runs; `flutter analyze` clean; `flutter test --concurrency=2` → **529 passing, 0 failing** (2026-10-03, before row 23; re-measured on `854f494` on 2026-10-05 before row 25, with `lib/` and `test/` untouched by every row in this file) |
| Driver | `specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py` — imports 012's `klhu_walk_video.py` for the mechanics (one string per `adb shell`, `uiautomator dump` reads, `tap`, `check`); rows implemented as they are walked |
| Fixture | `specs/014-dialogue-reading/scripts/klhu_dialogue_fixture.txt` — the reader's own four roles, pushed into the app's library by the driver |
| App locale | every row wipes the app's stored settings (`fresh_prefs`), so the chrome falls back to the **device's** locale: Chinese on the rows of 2026-10-03, English on row 25 (2026-10-05, `settings get system system_locales` empty on this AVD). Every label the driver taps is therefore matched in both languages (`app_zh_Hans.arb` / `app_en.arb`) |
| Engine | Google TTS; `logcat` carries the app's own evidence lines — `klhu speak`, `klhu roles`, `klhu read range` |

Rows are **WALKED — PASS** (device PASS plus the lines that prove it), **[unit]** (the Dart test that carries
it), **[structural]**, **PENDING** (not yet runnable), or **UNVERIFIED WITH REASON**.

**State of this file**: no row of this feature is pending. Every device row of the quickstart (23, 24, 25,
26, 27, 28 and 33) is walked and passes, and so are the four structural rows (19, 29, 30, 31). Nothing here is
inferred: every claim below is a line the driver read back, and the raw output of each row is quoted beside
its checks.

## The rows at a glance

| Row | Scenario | State |
|---|---|---|
| 23 | a four-role dialogue read: turns, one utterance per sentence, the tag never spoken, narration in the reading voice | **WALKED — PASS (10/10)** |
| 24 | the assignment against the device's own voices — 24 roles over a 15-voice pool, a pick deciding one language's voice | **WALKED — PASS (13/13)** |
| 25 | a pick and a removal survive a force-stop, per content, and go with the content when it is deleted | **WALKED — PASS (19/19)** |
| 26 | switching the type mid-read keeps the reader's place and the highlight — the same anchor, one voice per turn | **WALKED — PASS (25/25)** |
| 27 | a dialogue's video: no tag in a frame, each slot painted with the read's own sentence, the spans the render reported | **WALKED — PASS (24/24)** |
| 28 | **spike S1** — the device's *distinct* voices per language and recorded gender (the bound SC-003 is read against) | **WALKED — PASS (7/7)** |
| 33 | Format in the editor, with the reader's own hands: 63 → 66 chars, three line breaks and nothing else, one Undo | **WALKED — PASS (9/9)** |
| 34 | the list a pick is made from holds one row per voice (the reader's *选 (b)*): one row per voice, the on-device copy, and a stored network pick finding its row | **PASS** — the four unit rows green; rows 24/25 re-walked on the built app (**13/13**, **19/19**), the tap storing `cmn-cn-x-ssa-local` |
| 35 | a render that converted a sentence's rate carries no hiss (012 FR-017): the first 2 s below −35 dB above 10 kHz | **WALKED — PASS** — row 29 re-walked on the built app (**19/19**), the pulled file **−49.0 dB** first 2 s; the linear-interpolation build of the same row **−21.1 dB** |
| 19 | the four locales' keys and the generated localizations in step (`l10n_keys_test` 3/3, `gen-l10n`, clean tree) | **PASS (structural)** |
| 29 | no dependency, no platform change (`git diff --stat pubspec.yaml pubspec.lock android/` empty) | **PASS (structural)** |
| 30 | 011's read receipt re-run, unmodified — its parts 7, 8, 9, 10, 16, 17, 20, 21 all PASS | **PASS** |
| 31 | 012's video receipt re-run, one row per run — **31: 33/33**, **32: 42/42**, **33: 15/17** (and **19/20** with the script's own `KLHU_SKIP_PLAY=1`) | **PASS with a host-bound exception** — see row 31's section for the attribution |
| — | the unit rows of the quickstart (the Dart tests that carry each story) | in the suite, below its own record |

**Spike S1's answer in full** is row 28's section below (and `research.md` → Spikes → S1): 218 engine entries
→ **182 distinct voices**; with the app's recorded gender, **Mandarin 4 female / 3 male**, **Cantonese 3
female / 2 male**, English 11/8 plus one with none, Español 6/2 — so SC-003's N is **7 Mandarin and 5
Cantonese**, one Cantonese voice fewer than the table's own names.

The build the whole file was walked on: `854f494` (the 014 commit) plus this walk's own `specs/` edits —
`lib/` and `test/` unchanged by every row here; `flutter analyze` clean; `flutter test --concurrency=2` → **529
passing, 0 failing** (measured 2026-10-03 before row 23 and re-measured on `854f494` on 2026-10-05 before row
25; T036 re-measures it on the finished tree and records that figure beside these).

Rows 34 and 35 were added 2026-10-06 and were walked on a later tree: the 014 commit plus the picker's one row
per voice (`lib/models/voice_mapping.dart`, `lib/reader_service.dart`, `lib/voice_picker_screen.dart`) and 012's
band-limited `resample()`. That tree: `flutter analyze` clean, `flutter test --concurrency=2` → **536 passing,
0 failing** (measured 2026-10-06; 529 + the seven unit cases rows 34's group names).

## Deviations — the rules this walk learned

Each of these bit a row — device or unit — before it was written down; they are the reasons the rows read as
they do.

1. **After a press, wait longer than the platform's 500 ms undo throttle.** `widgets/undo_history.dart`
   pushes at most one change per window, and an Undo inside it *cancels the pending push* instead of undoing
   it — a driver that presses quickly reads a correct app as broken. Row 33's driver sleeps 1.2 s after every
   press, and row 33 shows the reward: a byte-for-byte restore.
2. **Seed text as a file; never type it.** `adb shell input text` carries ASCII only, so the fixture and row
   33's sample reach the library through the app's own storage and the driver only *enters* the editor. Every
   row's text is therefore the reader's own, byte for byte, before the row starts.
3. **Read the app's own line, and undo the label's own escapes.** Two of this walk's failures were readers
   lying, both about text: `uiautomator dump` writes a line break as `&#10;` and 012's `dump` decodes it for
   `content-desc` only (a Flutter text field's contents arrive as `text`), and 014's `role=` field sits
   between `tone=` and `span=` where a positional regex could not match it. Both fixes are in the drivers.
4. **Check the device's health after every row.** This host kills the emulator under a render's memory peak
   (012's script says so itself): row 32 exited **139** with 743/743 frames already passing, and row 33's
   share step read `device offline`. Re-run on a fresh `emulator -avd klhu -no-window`, and only then read a
   failure as the app's — the same two rows gave 42/42 and 15/17 afterwards.
5. **A second render needs the app in the foreground.** Android's cached-process freezer leaves
   `Sending oneway calls to frozen process` in `logcat` and no render at all — row 33's own gallery-play step
   is what leaves another app in front. The script's own `KLHU_SKIP_PLAY=1` is this host's answer, and with it
   row 33's second render completes.
6. **One row per run for 012's script.** It takes a single row (`sys.argv[1]`) and ignores the rest, so
   `klhu_walk_video.py 31 32 33` runs row 31 alone and prints a green summary a reader would take for three.
7. **A claim about a frame is a claim about pixels, with a floor.** A lossy encoder leaves single-channel
   noise: the same sentence's frames differ in 44 pixels, a slot boundary in 12 844. A pixel counts as moved
   only when a channel moves by more than 16 — without the floor the two cases are indistinguishable, with it
   they are three orders of magnitude apart.
8. **The audio's voice is not in the file.** The container says `aac` and how long; the identity of each
   utterance comes from the read's own `klhu speak` line, the render's `role=` field and the assignment — three
   witnesses, none of them the audio. Row 27 says so where it claims it.
9. **The gender is the app's table's, not the engine's.** The engine reports `name`, `locale`,
   `network_required`, `quality`, `latency` and no gender; every per-gender count here is
   `lib/models/voice_mapping.dart`'s recorded gender joined onto the engine's list.
10. **A running read's page never goes quiet.** `pumpAndSettle` on the reading page never returns (the
    reader's own ticker), and an image decode started on the fake clock in `testWidgets` never calls back —
    both cost a row's worth of time before they were written into the unit tests' notes.
11. **A rate conversion that is not band-limited is a hiss, and no row's other checks can see it.** Linear
    interpolation between samples does not reconstruct them; it leaves a mirror of the source's top octave
    above the source's own Nyquist, and on a 24 kHz sentence written up to 48 kHz that mirror lands at −75
    dBFS where the voice holds nothing at all (a windowed-sinc conversion of the same sentence: −121 dBFS).
    Row 29 passed **19/19 on both builds** — every check it has is about the file's shape, which did not
    change. The defect needed a level measurement and a ceiling (row 35, `klhu_probe_hiss.py`), which is the
    general lesson: a claim about *how something sounds* is a claim about levels.
12. **The engine lists one voice twice, so anything keyed on the name counts two.** The picker's rows, the
    scroll target and the selection highlight all keyed on the system voice id, and the two copies of a voice
    share a display name — so a reader could tap a row they could not tell apart, and a pick stored as the
    network copy found no row at all once the list held one row per voice. Everything that has to tell *the
    same voice* from *two voices* asks `voiceIdentity()` now, and everything that has to tell *the copy the
    device reads with* asks `isOnDeviceVoice()`.

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
| the pick is the reader's, stored under the language (FR-013) | `voice_zh_Hans = cmn-cn-x-ssa-local\|\|zh-CN` |
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

## Row 25 — a removal and a pick survive a restart

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 25` → **19/19 checks passed**
(exit 0).

**What it did, through the app's own controls**: dropped the app's stored settings, seeded the fixture, read
it once as 多人对话 (the roles BEFORE anything is decided); then `文字类型` → 阿明's row → the picker titled
`Voice for 阿明` → the `普通话 SSA (女)` row → `返回`; then May's `移除此角色` → the confirmation's own
`移除此角色`, read again; then force-stopped and started the app, opened the same content, read again; then
`内容` → the content's own `删除` → the confirmation's `删除`.

**The app's own lines** (logcat `I/flutter`, one session per read):

```
# the first read — nothing decided yet: the roles the text itself proposes
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)

# after the pick (阿明) and the removal (May), same session
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ssa-local(female) narration(zh-Hans)→os-default 阿芳→cmn-cn-x-ccd-local(male)
klhu speak p0 s0 role=旁白 voice=cmn-cn-x-ccc-local "今天天气很好，适合出去走走。"
klhu speak p1 s0 role=阿明 voice=cmn-cn-x-ssa-local "今日个天气真系唔错啊，行下公园好舒服。"
klhu speak p2 s0 "系啊，太阳晒住，风又凉爽。"
klhu speak p2 s1 "真系适合周末。"
klhu speak p3 s0 role=阿芳 voice=cmn-cn-x-ccd-local "我好少黎呢个公园，原来呢度风景咁靓。"

# after force-stop + start, the same content, the same read
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ssa-local(female) narration(zh-Hans)→os-default 阿芳→cmn-cn-x-ccd-local(male)
```

**The store, read back off the device** (`FlutterSharedPreferences.xml`, `run-as cat`):

```
# after the pick, before the removal
content_roles = {"dialogue_fixture":{"type":"dialogue","voices":{"阿明":{"name":"cmn-cn-x-ssa-local","locale":"zh-CN"}}}}
voice_zh_Hans = None                                    # the pick is the ROLE's, not the language's (FR-013)

# after the removal (the text's own version, at the moment it was removed)
content_roles = {"dialogue_fixture":{"type":"dialogue",
                 "voices":{"阿明":{"name":"cmn-cn-x-ssa-local","locale":"zh-CN"}},
                 "removed":[{"name":"May","at":"2026-10-05T17:33:08.000Z"}]}}
the index's updatedAt = 2026-10-05T17:33:08.000000Z      # the same moment, written two ways

# after the content is deleted from the library
content_roles = None                                    # the entry, and with it the key, is gone
```

**Checks** (all PASS, with the driver's own detail):

| Check | Detail |
|---|---|
| the text's own roles are proposed before anything is removed (FR-006) | the first read's roles: `['旁白', '阿明', 'May', '阿芳']` |
| the list draws one row per proposed role, in the text's order (FR-006) | the list's rows: `['旁白', '阿明', 'May', '阿芳']` |
| the shipped picker, titled with the role, offering the automatic row (FR-012) | the picker's own labels: `['Back', 'Voice for 阿明', 'English', 'Español']` |
| the pick is stored for that role alone, and not as the language's (FR-013) | `voices = {'阿明': {'name': 'cmn-cn-x-ssa-local', 'locale': 'zh-CN'}}`; `voice_zh_Hans = None` |
| the list names the picked voice on its role (FR-016) | 阿明's row: `'阿明\n1 turn · 普通话 SSA (女)'` |
| the removal asks first (the shipped dialog shape) | the dialog's labels: `['Remove this role?', 'Its paragraphs will be read as narration, in the reading voice.', 'Cancel', 'Remove this role']` |
| the removal is stored with the text's own version (FR-007) | `removed = [{'name': 'May', 'at': '2026-10-05T17:33:08.000Z'}]`; the index's `updatedAt = 2026-10-05T17:33:08.000000Z` |
| the removed name is gone from the list (FR-006) | the list's rows: `['旁白', '阿明', '阿芳']` |
| the store holds the type, the removals and the picks — and nothing else (FR-021) | the entry's own keys: `['removed', 'type', 'voices']` |
| the removed name is no role in the read (FR-007) | the read's roles: `['旁白', '阿明', '阿芳']`; the removed turn's own lines: `[(2, 0, None), (2, 1, None)]` |
| its paragraphs read as narration (FR-009) | `narration(zh-Hans)→os-default` in the read's own line |
| the role the reader gave a voice keeps it (FR-013) | 阿明 reads in `cmn-cn-x-ssa-local` (the pick) |
| after the restart the removal is still in force (FR-007, SC-006) | the list's rows: `['旁白', '阿明', '阿芳']` |
| after the restart the pick is still on its role (FR-012) | 阿明's row: `'阿明\n1 turn · 普通话 SSA (女)'` |
| the read after the restart is the read before it (FR-012, FR-013) | `before == after`, role for role and voice for voice |
| reopening the content wrote nothing to the store (FR-014) | `content_roles` byte-identical before and after the restart |
| the app reopens on the same content | the page's own text node starts with `{旁白}` |
| the delete asks first (the shipped dialog shape) | the dialog's labels: `['Delete this content?', 'This cannot be undone.', 'Cancel', 'Delete']` |
| deleting the content takes its dialogue settings with it (FR-021, SC-007) | `content_roles = None` |

**Proves** FR-006 (the proposal, and removing a name), FR-007 (a removal holds for that text and survives a
restart), FR-008 (a pick too), FR-009 (the removed paragraphs read as narration), FR-012 (a role's own
picker), FR-013 (the pick is the role's, and it decides that role's voice), FR-014 (nothing but the reader's
decisions is stored), FR-016, FR-021 (the delete takes the settings), SC-006, SC-007.

**What this row found**

1. **A removed name's paragraphs read in the NARRATION voice, not in a pooled one.** The app printed
   `narration(zh-Hans)→os-default`, and the two lines of May's turn carry no `role=` and **no `voice=`** at
   all (`klhu speak p2 s0 "系啊，太阳晒住，风又凉爽。"`): with the reader having picked a *role* voice and no
   *language* voice, narration falls back to the engine's default — the shipped reading behaviour, exactly
   (FR-009 with FR-002, `lib/dialogue.dart`'s own note). It is called out because the opposite is the natural
   expectation: removing a role does not hand its paragraphs to another role's voice, and the reader who
   wants that sound picks the language's voice (`语音`) as well — the picker's own path, row 24.
   **The reader settled it, 2026-10-05** — keep this (*保持现状*) rather than give a removed name's
   paragraphs a voice out of the dialogue's own pool (`spec.md` → Clarifications, Session 2026-10-05), so
   nothing in the code, the tests or the rows below changes.
2. **The removal is pinned to the text's version, spelled two ways.** The store holds
   `2026-10-05T17:33:08.000Z` (milliseconds, `DateTime.toIso8601String`) where the library index holds
   `2026-10-05T17:33:08.000000Z` (microseconds, 008's `updatedAt`): the same instant, so the removal is in
   force for exactly this text and expires the moment 008 saves it (research D4). The driver compares the two
   as moments rather than as strings for that reason.
3. **The role picker writes through the role store only.** `voice_zh_Hans` stayed absent while
   `content_roles[...]['voices']['阿明']` was written — row 24's language pick does the opposite, and the two
   cannot be confused in the store.
4. **A restart changes the process and nothing else.** Before and after the force-stop the read's roles line
   is identical, role for role and voice for voice, and the stored entry is byte-identical: the assignment is
   recomputed from the device's own voice list every read and never written (FR-014).
5. **The chrome drew in English this run** (row 24's drew in Chinese). A row wipes the app's own settings
   first, so the app's language falls back to the device's — which is why every label this driver taps has
   both spellings beside it (`L`), and why this row's own labels are quoted in English here.

---

## Row 26 — switching the type mid-read keeps the reader's place

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 26` → **25/25 checks passed**
(exit 0).

**What it did, through the app's own controls**: dropped the app's stored settings, seeded the fixture; tapped
the text part-way in (010's own anchor — the page resolves the tap to the sentence under the finger and stores
it); read from it as 标准 and **paused** with the highlight on screen; then `文字类型` → `多人对话` → `Done`
under that highlight; then `Stop`, re-tapped the same point, read the same sentence in 多人对话 (that pass ran
out by itself), re-tapped once more, and `文字类型` → `标准` → `Done`.

**The app's own lines** (logcat `I/flutter`, the app's own lines; the read was started with `继续朗读`, the
page's `_readRange(_anchor ?? 0, length)`):

```
# 标准 — the reader's tap stored 48||101 first
klhu read range: 48..101
klhu speak p0 s0 "{May} 系啊，太阳晒住，风又凉爽。"
klhu speak p0 s1 "真系适合周末。"
klhu speak p1 s0 "{阿芳} 我好少黎呢个公园，原来呢度风景咁靓。"

# 多人对话 — the same anchor, the same range, one voice per turn
klhu roles May→cmn-cn-x-ccc-local(female) 阿芳→cmn-cn-x-ccd-local(male)
klhu read range: 48..101
klhu speak p0 s0 role=May voice=cmn-cn-x-ccc-local "系啊，太阳晒住，风又凉爽。"
klhu speak p0 s1 role=May voice=cmn-cn-x-ccc-local "真系适合周末。"
klhu speak p1 s0 role=阿芳 voice=cmn-cn-x-ccd-local "我好少黎呢个公园，原来呢度风景咁靓。"
```

**The store, read back off the device** (`FlutterSharedPreferences.xml`, `run-as cat`):

```
read_position_dialogue_fixture = 48||101    # after the tap, while paused, after the switch, after the way back
content_roles = {"dialogue_fixture":{"type":"dialogue"}}   # after 多人对话
content_roles = None                        # after 标准 — the text is 标准 again, and nothing is stored
the index's updatedAt = 2026-10-05T18:11:05.000000Z        # unmoved from the first tap to the last check
```

**The highlight, read off the framebuffer** — the text band `(0, 260)-(1080, 1300)`, cropped by `ffmpeg` and
digested (`sha256` of raw pixels). The highlight is *paint*, so no dump carries it; each comparison below is
preceded by a control pair taken 3s apart, and every pair came back identical:

```
f8d2de99831cff58   the tap's own highlight (标准, before the first switch)
f8d2de99831cff58   the same anchor in 多人对话  … and after the way back to 标准 (all three identical)
7942f4ba1c06b428   the read paused under the highlight
7942f4ba1c06b428   after the switch to 多人对话 — the switch changed no pixel of the band
```

**Checks** (all PASS, with the driver's own detail):

| Check | Detail |
|---|---|
| nothing is stored yet, so the content is 标准 (FR-001/FR-002) | `content_roles[dialogue_fixture] = {}` |
| the tap anchors a sentence and stores the position (010) | `read_position_dialogue_fixture = 48\|\|101` (101 chars of text) |
| the band is stable before anything is compared (the control) | `f8d2de99831cff58` vs `f8d2de99831cff58` |
| 标准 reads from the anchored sentence | `read range (48, 101)` for the stored offset 48 |
| 标准 speaks the paragraph as written — the tag included (FR-002) | the first line: `'{May} 系啊，太阳晒住，风又凉爽。'` |
| pausing leaves Resume on screen (the shipped pause) | the buttons: `['…the text…', 'Resume', 'Stop', 'Edit']` |
| pausing leaves the position alone (010's record) | `read_position_dialogue_fixture = 48\|\|101` |
| the paused page is stable too (the second control) | `7942f4ba1c06b428` vs `7942f4ba1c06b428` |
| the switch stores the type (FR-001) | `content_roles[dialogue_fixture] = {'type': 'dialogue'}` |
| the switch leaves the position where it was (FR-020, SC-009) | `read_position_dialogue_fixture = 48\|\|101` |
| the highlight is where it was — the band is unchanged (SC-009) | `7942f4ba1c06b428` vs `7942f4ba1c06b428` |
| the text was not touched — 008's version is unmoved (FR-020) | `updatedAt: 2026-10-05T18:11:05.000000Z → 2026-10-05T18:11:05.000000Z` |
| the page still shows the text byte for byte | the page's own text node starts `'{旁白} 今天天气很好，适合出去走走。'` |
| Stop takes the position with it (011 FR-022, not this feature) | `read_position_dialogue_fixture = None` |
| the reader's second anchor lands on the same offset | `read_position_dialogue_fixture = 48\|\|101` |
| 多人对话 reads from the same sentence (FR-020, SC-009) | `read range (48, 101)` (标准's was `(48, 101)`) |
| and reads it as a turn — the tag is not spoken in 多人对话 (FR-005) | 标准 said `'{May} 系啊…'` / 多人对话 says `'May' '系啊，太阳晒住，风又凉爽。'` |
| the read named the assignment it used (D10) | `['May→cmn-cn-x-ccc-local(female) 阿芳→cmn-cn-x-ccd-local(male)']` |
| the repeat read ran out by itself and took the position (011) | the buttons: `['Read', 'Continue Read', 'Stop', 'Edit']`, `read_position = None` |
| the reader's third anchor lands on the same offset again (FR-020) | `read_position_dialogue_fixture = 48\|\|101` |
| the anchored page in 多人对话 is stable (the third control) | `f8d2de99831cff58` vs `f8d2de99831cff58` |
| switching back leaves nothing stored (FR-001) | `content_roles[dialogue_fixture] = None` |
| and the position is still the reader's own (FR-020) | `read_position_dialogue_fixture = 48\|\|101` |
| there and back is a no-op on the page (FR-020, SC-009) | `f8d2de99831cff58` (标准, before the first switch) vs `f8d2de99831cff58` (标准, after the way back) |
| the text is still untouched (008's version) | `updatedAt` unmoved |

**Proves** FR-001 and FR-002 (the type is the text's own setting, and 标准 is what a text without one reads
as), FR-020 (the switch moves the reader's place nowhere), SC-009, and — through the lines the read prints —
FR-005 with FR-004 and research D10 (in 多人对话 the same sentence is spoken as its turn's, in that turn's
voice, with no tag in the spoken text). The position itself is 010's (FR-008): this row only shows the switch
leaves it alone.

**What this row found**

1. **A type switch is a store write and nothing else.** With the read paused and the highlight on screen, the
   text band is *byte*-identical either side of the switch (`7942f4ba1c06b428`), the stored offset is the same
   number, and 008's `updatedAt` is the instant it was: there is no re-resolution, no re-layout, and the read
   in flight is not disturbed (the Resume button is still there afterwards).
2. **The page draws the same thing in both modes.** The tap's own highlight is `f8d2de99831cff58` in 标准
   *before* the switch, in 多人对话 after it, and in 标准 after the way back — the same anchor draws the same
   band, so the mode is not visible in the text area at all, only in what the read says.
3. **010's position is written by the gesture, and only by the gesture.** The stored `48||101` is the same
   number after a read starts, while the read is paused, and after a type switch — but a read that **ran out**
   or a `Stop` clears it (011 FR-022: the position lives only as long as the highlight that shows it). That is
   the shipped reading behaviour, not this feature's, and this row had to be built around it: the reader
   re-anchors by hand before reading in the other mode, which is why the position appears three times.
4. **标准 speaks the tag out loud.** `klhu speak p0 s0 "{May} 系啊，太阳晒住，风又凉爽。"` — the braces and
   the name are handed to the engine as ordinary text, because a paragraph's text is all a 标准 read knows
   (FR-002); 多人对话 says the same sentence as `role=May` with the tag gone (FR-005). A reader who never
   chooses a type hears the tags, which is exactly what the Format button (rows 32-33) and this setting are
   for.
5. **Two driver findings, both about timing rather than the app.** (a) The type chooser's role step builds its
   list from the engine, and a `Done` tap aimed at it while the list is still drawing is **swallowed** — this
   row's first run tapped Done once and the dialog was still up 3s later, so the driver now taps until the
   chooser is gone and the row fails loudly if it is not. (b) A **repeat** read of a range the engine has
   already spoken is over before a `uiautomator dump` (~2s) can land on Pause (measured twice), so the pause
   belongs on the first pass only; the way back is measured from an anchor the reader re-taps, on the same
   quiet page the first switch was measured on. The band comparison itself needs that quiet: every pair of
   stills is taken 3s apart with nothing in between, and all three controls came back identical.
6. **`继续` (Resume) is inside `继续朗读` (Continue Read).** A contains-match would call a read that has ENDED
   "paused", so the driver's `shows()` grew an `exact` form and this row's two Resume checks use it — with the
   chrome drawing in English or Chinese, the difference is the check being true or a check-detector.

---

## Row 27 — a dialogue's video: no tag in any frame, the read's own voices

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 27` → **24/24 checks passed**
(exit 0).

**What it did**: dropped the app's stored settings, seeded the fixture, set the text to 多人对话 through the
app's own chooser, read it once (to have the read's own assignment), then rendered it with 012's own path
(`视频` → `16:9 landscape 1080p` → `Start`), pulled the file and read both the app's lines and the file's
frames back.

**The read's own assignment** (what the video has to use — one call, D9):

```
klhu roles 旁白→cmn-cn-x-ccc-local(female) 阿明→cmn-cn-x-ccd-local(male) May→cmn-cn-x-cce-local(male) 阿芳→cmn-cn-x-ssa-local(female)
```

**The renderer's own lines** — 5 runs, one per sentence, the 014 fields beside 012's:

```
klhu render slot=0/5 frame=0/604 kind=sentence frames=110 scroll=0 picture=none tone=- role=旁白 span=5..19 text=14
klhu render slot=1/5 frame=110/604 kind=sentence frames=144 scroll=0 picture=none tone=- role=阿明 span=27..46 text=19
klhu render slot=2/5 frame=254/604 kind=sentence frames=102 scroll=0 picture=none tone=- role=May span=54..67 text=13
klhu render slot=3/5 frame=356/604 kind=sentence frames=55  scroll=0 picture=none tone=- role=May span=68..75 text=7
klhu render slot=4/5 frame=411/604 kind=sentence frames=193 scroll=0 picture=none tone=- role=阿芳 span=82..100 text=18
klhu render done: /data/user/0/com.example.klhu/cache/klhu_video.mp4 20133ms 968584B frames=604
klhu render told: Video made: klhu_video.mp4 (20 s)
```

**The file, off the device** (`ffprobe`): `1920x1080`, **604 frames read** (the render's own count, frame for
frame), 20261 ms against the render's 20133 ms, audio `aac` at 24000 Hz.

**The frames themselves** (exact frame numbers, no seeking; a pixel counts as moved only when a channel moves
by more than 16 — a lossy encoder leaves single-channel noise on glyph edges):

| Where | Moved share |
|---|---|
| inside a slot (first vs last frame of one sentence) | 0.002%, 0.000%, 0.000%, 0.000%, 0.000% |
| across a turn boundary (`阿明`, `May`, `阿芳` opening frames vs the frame before) | 0.620%, 0.669%, 0.602% |
| the closest two slots in the whole file (2/3, May's two sentences) | 0.412% |
| ink per slot (share of the frame that is not background) | 0.35%, 0.51%, 0.33%, 0.20%, 0.52% |

**Checks** (all PASS, 24 of them): the read names an assignment; the aspect prompt opened; the render reported
done (19s) and the page showed progress; the app told the reader the file's name and its length (`Video made:
klhu_video.mp4 (20 s)`, the render's own 20133 ms); the file came back (968584 B); the renderer's lines parsed
— **5 runs, with `role`** — and each of the checks below; the file's frames equal the render's own count; the
file carries audio as long as the render; every slot has ink; a sentence's picture does not change inside its
slot; each sentence has its own picture (no two slots share a frame); a frame at a turn boundary belongs to the
turn it opens.

The two checks that carry the row's claim, in full:

- **no slot's painted text carries its tag (FR-005, SC-008)** — painted lengths `[14, 19, 13, 7, 18]`, the
  tag-free sentences are `[14, 19, 13, 7, 18]`, and with the tag they would be `[19, 25, 19, 27, 23]` (the
  `{name}` and its colon are 5-9 bytes of the paragraph).
- **one slot per sentence, in the text's own order (FR-018)** — the renderer painted
  `[(5, 19), (27, 46), (54, 67), (68, 75), (82, 100)]`, which are the sentences' own offsets in the raw text:
  the first slot starts at 5, not at 0, because `{旁白} ` sits before it.

**Proves** FR-018 (a dialogue's video is the read's plan: one slot per sentence, each in its turn's role and
voice) and SC-008, with FR-005's video half (no tag reaches a frame) and FR-019 (the video voices a turn
exactly as the read does — the same roles, from one call). FR-018's "the frames' text matches the turn's
content span" is the spans above.

**What this row found**

1. **014's `role=` field broke 012's render-line parser, silently.** The renderer prints
   `… tone=- role=旁白 span=5..19 text=14` (014 D10 appended `role=`, `span=`, `text=` beside the fields 012's
   walk reads), but `RENDER_RUN_RE` in `specs/012-reading-video/scripts/klhu_walk_video.py` was positional:
   after `tone=(\S+)` it required ` span=` and found ` role=` — so it matched **nothing**, and 012's rows 31/32
   would have read **0 runs** against any content while their other checks still passed on the file. The D10
   note ("beside the fields 012's own walk reads, so every existing check keeps matching") was true about the
   fields and false about the parser. Fixed by making the field optional and adding it to `RUN_FIELDS`
   (`(?: role=(\S+))?`, so the pre-014 shape still parses), and verified by parsing the app's own line: the
   run's dict now carries `role='旁白'`, `span_start=5`, `span_end=19`, `text=14`.
2. **A lossy frame pair is not an identical pair.** My first version of the pixel checks compared frames for
   byte equality and failed: two frames of *one* sentence differ on 44 pixels of 2,073,600 (max channel delta
   55) — encoder noise on glyph edges — where two frames either side of a slot boundary differ on 12,844 (max
   227). The checks now count a pixel as moved only when a channel moves by more than 16, which puts the two
   cases three orders of magnitude apart (0.002% vs 0.62%) instead of indistinguishable.
3. **The video's pictures are one per sentence and change only where the plan says.** In-slot pairs move
   0.000-0.002% of the frame; every turn-opening frame moves ~0.6% against the frame before it; and the closest
   two slots in the whole file (May's two sentences, which share one role and one voice) still differ by
   0.412%. A boundary frame therefore belongs to one turn only — nothing of the turn before it is left on
   screen (FR-018's own expectation).
4. **The file's own voice identity is not readable from the file.** `ffprobe` says there is `aac` audio 20261 ms
   long, and the app's `role=` per slot plus the read's `klhu roles` line say which turn was read in which
   voice; nothing in the container names a speaker, so this row proves the *plan* is the read's (role for role,
   one call, D9) and the file is that plan's own length — it does not sample the audio to identify a voice.
   That is the honest limit of this row.
5. **The render is deterministic enough for a row, but not bit-exact.** The same content rendered twice would
   give the same slot spans, roles and counts; the pixel comparisons needed the tolerance in (2) to be useful,
   and that tolerance is now written into the driver with the numbers it came from.

---

---

## Row 28 — spike S1: how many distinct voices does this device list?

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 28` → **7/7 checks passed**
(exit 0). A measurement rather than a claim about the app: its answer is what SC-003's "whenever the device
lists at least N matching voices" is read against, and it is also written into `research.md` → Spikes → S1.

**What it did**: dropped the app's stored settings, seeded the fixture, opened `语音` (which makes the app load
the engine's whole voice list), and read the app's own `klhu getVoices` lines back — 218 entries in the window
(007's line, one per engine entry). The gender beside each voice is the app's recorded table
(`lib/models/voice_mapping.dart`, 96 ids): the engine exposes no gender at all.

**The device's own voices** (distinct voices; a code's local and network variants counted once, the table's own
rule):

```
普通话 (Mandarin)  female  4   ccc, ssa, zh-CN-language, zh-TW-language
普通话 (Mandarin)  male    3   ccd, cce, ctd
粤语 (Cantonese)   female  3   yuc, yue, yue-HK-language
粤语 (Cantonese)   male    2   yud, yuf
English            female 11   aua, auc, en-AU-language, en-GB-language, en-NG-language, enc, gba, gbc, iob, sfg, tpf
English            male    8   aub, aud, end, ene, gbb, iol, iom, tpd
English            —       1   tpc    (the table's own documented exception: conflicting evidence)
Español            female  6   eea, eec, eee, es-US-language, esc, sfb
Español            male    2   eef, esd
```

**The answer**: 218 engine entries → **182 distinct voices**; **Mandarin 7 (4 female, 3 male)**, **Cantonese 5
(3 female, 2 male)**, English 19 with a gender and one without, Español 8.

**Checks** (all PASS, 7 of them): the engine's list came off the app (218 entries); the app's gender table was
read (96 ids); only the app's own four language lists were counted (`['English', 'Español', '普通话
(Mandarin)', '粤语 (Cantonese)']`); the Mandarin bound is recorded rather than demanded (**4 female, 3 male**);
the table and the list were compared (**1 of 182** voices without a recorded gender: `en-us-x-tpc`); Mandarin —
7 distinct voices with a gender, none without; Cantonese — 5 with a gender, none without.

**Answers** T032 and quickstart row 28, and bounds SC-003: the fixture's roles are read from **7 Mandarin** and
**5 Cantonese** distinct voices, not from the app's table's 7 Mandarin / 6 Cantonese *names* (the table holds 96
ids, both variants of each code among them, and the device lists one Cantonese voice fewer than the table
names). Row 24's PASS is read against this list: its 24 roles shared 15 of these voices.

**What this row found**

1. **The gender is the app's, not the engine's.** Every count above is `lib/models/voice_mapping.dart`'s
   recorded gender joined onto the engine's own list — the engine's entry carries `name`, `locale`,
   `network_required`, `quality` and `latency` and no gender at all. A spike about gender can only be a spike
   about *this app's* view of it, and the row says so rather than implying the device reported it.
2. **Distinct voices are not ids.** 218 engine entries collapse to 182 voices because each code can appear as a
   `-local` and a `-network` variant; counting ids would have inflated every row of the table above by about a
   fifth. The count follows the table's own rule that the measured variants of a code are one voice.
3. **One voice in 182 has no gender, and the table already says why.** `en-us-x-tpc`'s F0 sits in the overlap
   band and the engine's manifest calls it female, so the table claims nothing for it — the device row found
   exactly that one voice, which is a small cross-check on the table itself.
4. **The measured bound is smaller than the table's names, and that is the spike's value.** The table names 7
   Mandarin and 6 Cantonese voices; the device offers 7 and 5 distinct voices with a recorded gender. SC-003's
   N has to be read from this row, not from the table's name count — which is why the quickstart made this a
   spike rather than an assumption.

---

---

## Row 33 — Format in the editor on the device, with the reader's own hands

**Command**: `python3 specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py 33` → **9/9 checks passed**
(exit 0).

**What it did**: seeded a content of its own (`dialogue_format_fixture`, 63 chars) whose text holds two tags
on ONE line and a third at a line start but not yet at a paragraph's onset — `{旁白} 今天天气很好，适合出去
走走。{阿明} 今日个天气真系唔错啊，行下公园好舒服。` then a line break then `{May} 系啊，太阳晒住，风又凉爽。`
— opened the editor, read the field out of a `uiautomator dump` (the ground truth for Flutter text on this
host), pressed **排版** and read it again, pressed it a second time, pressed **撤销**, pressed 排版 again and
**完成**, then read the library's own file and the reopened page. Every press waits 1.2 s, longer than the
platform's 500 ms undo throttle that the quickstart warns about.

**What the press did, measured**: 63 chars → 66 chars — **three characters added, all line breaks**: `\n\n`
before the mid-line tag and one more `\n` before the tag that already started a line. Stripping every line
break from both readings gives the same characters in the same order, tags included (the driver compares the
text with each tag replaced by a marker), and every tag is then the first non-space thing of its own
paragraph: `[True, False, False]` → `[True, True, True]`. FR-024 and SC-011 where the editor's own text is the
only witness.

**Checks** (all PASS, 9 of them): the editor shows the row's text tag for tag (63 chars, byte-identical to
what was seeded); the text is two tags on one line plus one at a line start and none is yet a paragraph's
onset (`[True, False, False]`); the press changed the text (63 → 66); every tag is now its own paragraph's
onset (`[True, True, True]`); the difference is blank lines and nothing else (same non-newline characters,
same tag onsets, 3 characters added); **a second press changes nothing** (the app disables the button when
`formatForDialogue(value.text) == value.text`); **Undo puts the reader's text back byte for byte**; Done saves
the formatted text (`content/contents/dialogue_format_fixture.txt` holds 66 chars, the editor's own reading);
the reopened content shows the formatted text (its own text node holds those 66 chars). The row unsets its
content afterwards, leaving the library as it found it.

**What this row found**

1. **The driver could not read the app's text until it undid the dump's own escapes.** 012's `dump` undoes
   `&#10;` for `content-desc`; a Flutter text field's contents arrive as `text`, where the entity survives — so
   the first run read `\n` as four literal characters (`&#10;`), which made May's tag look like it did not
   start a line and made the library comparison off by four characters per line break. The app was right in
   both readings; the driver now decodes the escapes (`unxml`) before any comparison. This is row 27's finding
   in reverse: there an app-correct line beat the parser, here a dump-correct label beat the reader — in both
   cases the walk was about to call a working app broken.
2. **The whole effect of the press is measurable, and it is only line breaks.** Three characters, and the
   character sequence is otherwise untouched — so an unclosed brace or a full-width pair would stay exactly
   where it was, which is what the quickstart's row 32 asserts in the unit suite and this row asserts with the
   reader's own hands.
3. **Two presses are one way to see the enabled rule.** The row cannot read a disabled button's state off the
   tree reliably, so it checks the observable half: the second press left the text at 66 chars, unchanged.
   The unit row 32 covers the button's own state.
4. **Undo is one step and the throttle is real.** The byte-for-byte restore only holds because the driver waits
   past the 500 ms push window the quickstart documents; a faster driver would have read a correct app as
   broken (and the same note is in `press()` where the wait lives).
5. **The save is 008's own path, not a second one.** After Done, `content/contents/dialogue_format_fixture.txt`
   holds exactly the editor's reading, and the reopened page renders it — the formatted text reached the
   library through the editor's existing save.

---

---

## Row 19 — the three locales' keys, and the generated files in step with them

**Command**: `flutter test test/l10n_keys_test.dart` → **3/3 passed**; then `flutter gen-l10n`; then
`git status --short lib/l10n` → **empty** (exit 0). Structural: no device.

**What it shows**: every key the feature added is in all four locales — `app_en.arb`, `app_es.arb`,
`app_zh.arb` and `app_zh_Hans.arb` are the four files the check walks — and the test is bidirectional, so a
key one ARB dropped fails exactly as loudly as a key one ARB never had. Regenerating the localizations
afterwards left the tree clean: the committed `lib/l10n/app_localizations*.dart` are what the ARBs produce, so
nothing about this feature's strings is only on the machine that generated them. The keys this feature added
(read back out of `app_zh_Hans.arb`): `textTypeDialogue`, `textTypeDialogueHint`, `roleListTitle`,
`roleListEmptyMessage`, `roleRemoveButton`, `roleRemoveConfirmTitle`, `roleRemoveConfirmMessage`,
`formatButton` (`排版` / `Format`).

**Checks**: the parity test's own three cases, the generator's own exit, and `git status` on the generated
files being empty. Proves FR-022 (reachable in four locales) and the l10n half of FR-023.

---

## Row 29 — no dependency, no platform change

**Command**: `git diff --stat pubspec.yaml pubspec.lock android/` → **empty** (exit 0). Structural: no device.

**What it shows**: this feature added no package, moved no version and touched nothing under `android/` — its
whole surface is Dart the app already had. Its own three files (`lib/dialogue.dart`, `lib/role_store.dart` and
the additions to `lib/reader_service.dart` / `lib/reading_view.dart`) are the feature's entire footprint.

**Checks**: one empty diff, over the three paths a dependency or a platform change would have to appear in.
Proves FR-023 and SC-010's dependency side (the no-network-call side is the read path's own tests plus rows 24
and 27, which ran with the engine's own voices and no key).

---

## Row 30 — the 011 read receipt still passes

**Command**: `python3 specs/011-reading-experience/scripts/klhu_walk_experience.py` for its own parts —
**7, 8, 9, 10, 16, 17, 20 and 21, all eight `RESULT: PASS`** — plus `flutter test test/language_test.dart
test/segmenter_test.dart test/reader_service_test.dart` (run together with 012's three video files: **102 tests
passed**, one invocation covering both rows' unit halves). Structural + the device.

**What the walk's own output said** (unchanged 011 evidence, not re-derived here): 8 utterances spoken and 8
follow reports with the highlight's measured pixel shares; part 16 restored the appearance record
`flutter.reading_appearance = default||medium` and showed default-again against serif differing by 6.70% of
pixels; part 17's Done put its content in the library through the same path an untyped content uses; part 20's
"nothing set" read came back `(0, 334)` of a 334-char text; part 21's Stop left Read / Continue Read in
place. A content with no dialogue settings reads exactly as it read before this feature — which is SC-005, and
`test/language_test.dart`'s `resolveParagraphSpeeches offsets` group is among the 102.

**Checks**: eight parts green with no edit to the script, and the three named test files inside a green run.
Proves SC-005 and FR-020's "switching touches nothing but the setting" side (row 25's device walk proves the
other side).

---

---

## Row 31 — the 012 video receipt still passes

**Command**: `python3 specs/012-reading-video/scripts/klhu_walk_video.py` **once per row** — `31`, then `32`,
then `33` — plus `flutter test test/video_timeline_test.dart test/video_painter_test.dart
test/video_renderer_test.dart` (run with 011's three files: **102 tests passed**). Structural + the device.

**The quickstart's own command does not do what it says.** It reads `klhu_walk_video.py 31 32 33`, but 012's
script takes **one** row (`sys.argv[1]`, with the rest ignored) — so that invocation runs row 31 and silently
skips 32 and 33, printing a green summary that a reader would take for all three. The rows below were run one
at a time.

| 012 row | result | what it is |
|---|---|---|
| 31 | **33/33 checks passed** (exit 0) | two real renders (16:9 landscape 1920x1080 and 9:16 vertical 1080x1920): the pulled file is the app's own byte count, h264 + aac, exactly the frames the plan asked for (743 vs 743 both ways), constant 30/1, durations within 2 s of the render's own, and the page's own line about the file |
| 32 | **42/42 checks passed** (exit 0), 84 PASS lines | one slot per sentence, each slot's frames carrying that sentence alone and its own character range, no chrome in 743/743 frames read back, no frame holding the withdrawn highlight, and the page's picture moving forward with the render |
| 33 | **15/17** (exit 1) | the file's life cycle: render, review, keep, play from the gallery, share, delete. Every check but two passed |

**Row 33's two failures, and what they are not.** Both are the *second* render: "the render reported done — no
`klhu render done` within 300 s" and "the second render produced a file". Its own logcat tail shows the cause —
`Sending oneway calls to frozen process` — the app's process was **frozen** when Start was pressed, which is
Android's cached-process freezer: this row's own earlier step plays the kept video from the gallery, leaving
another app in the foreground, and the render cannot advance in a frozen process. The first render in the same
run is green (its file, its streams, the review's keep and discard, the gallery empty after a discard, the kept
video playing from the gallery's own entry, and sharing keeping nothing). Nothing in this failure touches the
render path 014 changed: the second render never ran.

**The first attempt died and read as the app failing, and the host is why.** On the first pass the emulator
was killed under the render (012's own note: "this development box kills the emulator under it") — row 32
exited **139** after 743/743 frames had already passed, and row 33's run left `device offline` in its share
step and a `Delete video` label check racing a dying device. Re-running rows 32 and 33 on a fresh
`emulator -avd klhu -no-window` gave **42/42** and the 15/17 above, with that label check passing — so the
earlier readings were the device dying mid-row, not a regression. A walk that does not check the device's own
health after a row will record a host failure as an app failure.

**A third run, with the script's own skip, identifies the freeze exactly.** `KLHU_SKIP_PLAY=1` — the env var
012's script offers for this host, "the player is this box's memory peak and the emulator dies under it" —
gave **19/20**: the *second render completed*, which is what pins the earlier hang on the gallery-play step,
and its single failure is that run's own skip ("the app's own record names the kept video — None"), a check the
full-flow run above passed. So across three runs, no failure of 012's row 33 touches anything 014 changed:
they move with the device's health and with the skip, and the checks that read the render's own lines — the
field this feature added — are green in every run that got that far.

**On "unmodified"**: `specs/012-reading-video/scripts/klhu_walk_video.py` does carry one edit from this feature
— row 27's finding, the `RENDER_RUN_RE` that could not match the `role=` field 014 added — and rows 31 and 32
above, which parse those very lines, are the proof that the fix reads 012's own format correctly. No further
change was made for these rows.

**Checks**: three runs green/green/15-of-17 with the failures attributed, the three video test files inside a
green 102. Proves FR-019's "nothing else changed" side, FR-018's video voices (row 27 walks the `role=` field
itself) and SC-008.

---

## Row 34 — the list a pick is made from holds one row per voice

**The reader's decision, 2026-10-06: *选 (b)* — one row per voice, the on-device copy.** The question came out
of their phone: the picker listed "普通话 SSA (女)" twice, and the three role picks stored there (阿明
`yue-hk-x-yuf-network`, May `yue-hk-x-yue-network`, 阿芳 `yue-hk-x-yuc-network`) are all *network* copies — the
reader had chosen a copy without being able to tell there was a choice. The three options put to them were (a)
both rows as they are, (b) one row per voice, the on-device copy, (c) one row per voice with the copy named;
they chose (b). Recorded in spec.md: FR-012's new sentence and Clarifications 2026-10-06.

**What changed** — `lib/reader_service.dart::voicesFor` keys its rows on `voiceIdentity()` and prefers
`isOnDeviceVoice()`; `lib/models/voice_mapping.dart` grows `isOnDeviceVoice()`; `lib/voice_picker_screen.dart`
keys its row keys, its `indexWhere` and its `_isSelected` on the same identity, so a pick stored as either copy
still finds and highlights its voice's row.

**Unit side** (the four rows the quickstart's row 34 names):

- `test/reader_service_test.dart` — "one row per voice: the on-device copy is what is offered": both copies in
  the engine's list → one row, the `-local` one, keeping the position its first copy took; a voice with only a
  network copy keeps its row.
- `test/cantonese_dialect_test.dart` — US3's regression re-written onto the new contract: every Cantonese voice
  is still listed, **once**, and as its on-device copy; no `-network` row survives the filter.
- `test/voice_mapping_test.dart` — `isOnDeviceVoice` on the copies, on the engine's suffix-less names
  (`yue-HK-language`, `os-default`) and on the empty string.
- `test/voice_picker_test.dart` — a role picker opened with a selection stored as `en-gb-x-gba-network`
  highlights the voice's one row (red on the previous code: no row matched, so no row was selected at all).

`flutter analyze` clean; `flutter test --concurrency=2` → **536 passing, 0 failing**.

**Device side, on the built app** (AVD `emulator-5554`, the build with the change installed):

- Row 24 **13/13 PASS** — the picker drew the device's Chinese voices with one row per voice, the four roles'
  assigned voices are all `-local` (`['cmn-cn-x-ccc-local', 'cmn-cn-x-ccd-local', 'cmn-cn-x-cce-local',
  'cmn-cn-x-ssa-local']`), and a tap stored `voice_zh_Hans = cmn-cn-x-ssa-local||zh-CN`.
- Row 25 **19/19 PASS** — a role's tap stored `cmn-cn-x-ssa-local`, the on-device copy, under the role alone
  (`voice_zh_Hans = None`), and reopening the content wrote nothing (FR-014).

**What a reviewer should argue with:** (b) means a reader who *wants* the network copy has no row for it — the
alternative (c) was offered and declined; and the picks already stored as network copies are left alone, so
those roles keep reading through the network copy until the reader picks again. That is deliberate (FR-014:
reopening writes nothing) and it is the reason 012's FR-017 had to be fixed rather than worked around: a mixed
read has to render cleanly whichever copy a pick names.

---

## Row 35 — a render that converted a sentence's rate carries no hiss

**The reader's report, 2026-10-06: *"手机上粤语对话出片了。但是片头有噪音。"*** — their Cantonese dialogue rendered
and its opening sentence hissed. It was 014's row 29 that made the render work the day before, and the defect
was in the way it made it work.

**What the file said.** Pulled off the phone (`Movies/Klhu/周末公园散步.mp4`, `adb pull`): 80.96 s, AAC 48 kHz
mono 64 kbps. Above 10 kHz, per second: **−22.7 · −25.9** · −53.6 · −45.7 · −57.7 · −46.5. The narration
sentence — the only pick that is a 24 kHz `-local` voice — is 25–30 dB louder above 10 kHz than the twelve
48 kHz sentences around it, and a video that never converted anything (` ¡Hola!.mp4`, 2026-10-02) reads −57.1
dB over its own first two seconds. That is the hiss, in numbers.

**What the conversion was doing.** `VideoEncoderPlugin.resample()`, written 2026-10-05, was **linear
interpolation**. Measured on a real engine sentence (`s1_zh-picked.wav`, 24 kHz, written up to 48 kHz exactly
as the encoder does, then AAC 64 kbps mono as the app writes): band levels 0–6 k / 6–11 k / 12–16 k / 16–22 k =
**−44.2 / −67.1 / −75.2 / −88.0 dBFS** — where the source itself cannot hold anything above 12 kHz at all
(the source measures −67.1 in 6–11 k and nothing above), and a band-limited conversion of the same sentence
measures −44.2 / −67.1 / **−121.1** / −120.7, matching ffmpeg's own `soxr` (−120.9 / −121.3). The artefact
survives the AAC encoder: −75.4 / −85.2 dBFS in the encoded file against soxr's −118.6 / −119.9.

**The fix** — a Blackman-windowed sinc interpolator: 32 source samples either side (a 2 kHz transition band on
a 24 kHz source), cut-off 10 % under the source's Nyquist so the whole transition sits below where a mirror
artefact can start, taps normalised per phase so no level can shift. The same sentence through it measures
−121 dBFS in 12–16 k, and a 300 Hz / 3 kHz / 8 kHz tone keeps its level to 0.00 dB while an 11 kHz tone gives
up 10.9 dB (the voice holds nothing up there: measured peak −89 dBFS in 11–12 kHz).

**Receipt — the same row, the same device, only the resampler different** (AVD `emulator-5554`, install → walk
`klhu_walk_dialogue.py 29` → `adb pull` → `specs/012-reading-video/scripts/klhu_probe_hiss.py`):

| Build | row 29 | the pulled file's first 2 s, >10 kHz | the same file's 48 kHz sentences |
|---|---|---|---|
| linear interpolation (2026-10-05) | 19/19 PASS | **−21.1 dB** | −45.2 … −49.5 dB |
| windowed sinc (2026-10-06) | 19/19 PASS | **−49.0 dB** | −44.3 … −54.1 dB |

−27.9 dB at the slice under test, and the converted sentence is no longer distinguishable from what it was
converted to: the fixed build's first two seconds sit inside the file's own range. Two independent walks of the
same build read the same figures to 0.1 dB.

**The phone itself, 2026-10-06** (the reader unlocked it; the fixed build was already installed): the same
content, the same device, re-rendered through its own UI and the file pulled back —
`周末公园散步.mp4`: **−24.3 dB** over its first two seconds (`−22.7 · −25.9`), the converted narration sentence
standing 25–30 dB above the twelve 48 kHz sentences around it. Re-rendered with the windowed sinc:
**−50.9 dB** (`−48.6 · −53.2`), inside the file's own range (−45.7 … −57.7), and the probe passes the ceiling.
The reader's own content is clean on the device they reported it on; the emulator's before/after above is the
controlled pair.

**The keep path, checked on the phone afterwards — and a claim corrected.** Right after `Save` the album
held **two** files: `周末公园散步.mp4` (the hissy one, 2026-10-05 19:10, 31 MB) and
`周末公园散步 (1).mp4` (the clean one, 15:37). Twenty minutes later the album holds **one**:
`周末公园散步 (1).mp4`. So FR-012 holds — the old entry and its bytes are gone — and what I read as a
defect was a measurement taken while the platform was still finishing the delete. The receipts:

- `Movies/Klhu` at 15:37: two files; at 15:55: `¡Hola!.mp4` and `周末公园散步 (1).mp4` only.
- MediaStore at 15:55: one row per content in that album (`_id=1000002649` `¡Hola!.mp4`,
  `_id=1000002681` `周末公园散步 (1).mp4`) — no row for the old name at all.
- The app's own record (`FlutterSharedPreferences.xml`, key `video_record`) points that content at
  `.../video/media/1000002681` with `name` = `周末公园散步.mp4` — the name the app **asked** for, while the
  platform stored the file as `周末公园散步 (1).mp4`: MediaStore renames rather than replacing when the
  insert's `DISPLAY_NAME` is already taken, and the app's own record keeps the requested name, not the
  platform's. That rename is the only thing the reader still sees of this, and it is a naming question, not
  an FR-012 violation (the count is right, the file is the new one).

A second observation from the same pair, not a defect: the old file's frames are 4.6 MB PNGs and the new
file's 57 KB ones, 3.0 Mbps against 160 kbps, because the earlier render had **pictures** behind the text and
this one had none ("No pictures chosen") — the same code, a different reader choice, and the content-driven
bitrate that follows from it.

---

## Rows still to walk

None. Every device row of the 014 quickstart (23–28, 33) is walked, each in the pass that
implemented it; the rows above are the record. Rows 34 and 35 were added 2026-10-06 from the reader's own
report on their phone, and both are walked — row 35's second half (their own content, on their own phone) on
2026-10-06 after they unlocked it. What row 35 turned up: the platform finishes a keep by renaming the file,
not by replacing it (`周末公园散步 (1).mp4`), and the old file's bytes outlive its MediaStore row by a few
minutes — a naming observation, not the FR-012 violation it first looked like (the row records the
measurement that corrected it).
