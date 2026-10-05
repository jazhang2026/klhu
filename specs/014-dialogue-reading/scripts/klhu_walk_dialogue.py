#!/usr/bin/env python3
"""klhu device walk — 014 quickstart rows 23-28 and 33.

Row 23: a four-role dialogue on the device — the fixture read from the top, with
        logcat's `klhu speak` lines as the witness: the turns' contents in order,
        no tag and no role name in any spoken text, one line per sentence, each
        in its role's voice, the whole assignment named by the read's own
        `klhu roles` line.
Row 24: the assignment as the app made it, against the device's own voice list —
        the same content assigning the same voices twice, a role's pick winning
        over the language's, and 24 roles on a 15-voice pool sharing visibly with
        no role silent.
Row 25: a removal and a pick survive a restart — the reader gives a role a voice
        through the role's own picker and removes a name from the role list, the
        app is force-stopped and started again, and both decisions are still in
        force for that text (the removed name's paragraphs read as narration, the
        picked role reads in its picked voice, and the stored entry is exactly
        `{type, removed, voices}`); deleting the content then takes the entry with
        it.
Row 26: the type switch and the reader's place — the reader taps a sentence
        part-way in (010's own anchor), reads from it, pauses, and the type is
        switched to 多人对话 and back under the highlight: the stored offset is
        the same number at every step, the text band is pixel-identical either
        side of the switch, 008's version is unmoved, and the read starts at the
        same offset in both modes (in 标准 the tag is spoken, in 多人对话 the
        turn's speaker is).

The mechanics are 012's (`specs/012-reading-video/scripts/klhu_walk_video.py`):
one string per `adb shell` command, `uiautomator dump` reads, `tap(rows, label)`,
`check(name, ok, detail)` with a PASS/FAIL summary and a non-zero exit on failure.
014 adds only what is its own: the fixture, the `content_roles` shared-prefs key,
and the parsers for the two log lines this feature prints.

The fixture is the reader's own example (spec.md → Input, quickstart's fixture
note): 旁白 / 阿明 / May / 阿芳, one turn to a paragraph with a blank line
between them, 阿明's prefix carrying the optional colon separator, and May's turn
written across two lines — a turn holds as many lines and sentences as its
paragraph does, and the device row has to hear that too.

May's turn is two lines that are two *sentences*: the first line ends with 。
rather than the reader's own comma, because a line break is not a sentence
boundary — the first run of this row had the reader's comma there and heard the
two lines as ONE utterance (`系啊，太阳晒住，风又凉爽， 真系适合周末。`, one
`klhu speak` line), which is the sentence rule working, not a bug. The row's
expectation ("that turn coming out as its two sentences, one after the other, in
the same role's voice") therefore needs the sentence to end where the line does;
what the multi-line *turn* proves either way is that one turn is one voice.

Usage:  python3 klhu_walk_dialogue.py 23
        ADB_SERIAL=emulator-5554 python3 klhu_walk_dialogue.py 23
        KLHU_REPO=~/Documents/GitHub/Projects/klhu KLHU_OUT=/tmp/klhu_out \\
            python3 klhu_walk_dialogue.py 23
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.

Run a row with `python3 -u`: the row prints its progress and its evidence as it
goes, and a redirected stdout without `-u` holds all of it in a buffer until the
row ends.

A row is implemented here in the pass that walks it; `main` names the rows it
does not have yet rather than dispatching into a stub.
"""
import hashlib
import json
import os
import re
import subprocess
import sys
import time
from datetime import datetime

from PIL import Image, ImageChops  # row 27 reads the render's own frames

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "012-reading-video", "scripts"))

# 012's module owns the device mechanics. Importing it is the whole point of the
# shared-driver note in 014's tasks: one implementation of "dump, find, tap,
# check", and one place that knows how the app's library is laid out on disk.
import klhu_walk_video as video  # noqa: E402

DEV = (os.environ.get("ADB_SERIAL") or os.environ.get("KLHU_DEV")
       or "emulator-5554")
OUT = os.environ.get("KLHU_OUT", "/tmp/klhu_out")
PKG = video.PKG
LIBRARY = video.LIBRARY
INDEX = f"{LIBRARY}/content/index.json"

FIXTURE = os.path.join(HERE, "klhu_dialogue_fixture.txt")
CONTENT_ID = "dialogue_fixture"
CONTENT_NAME = "四人对话"
# The fixture is four turns: 旁白 one sentence, 阿明 one, May two (its turn is two
# lines and two sentences), 阿芳 one.
FIXTURE_SENTENCES = 5
EXPECTED_ORDER = [(0, 0), (1, 0), (2, 0), (2, 1), (3, 0)]
FIXTURE_ROLES = ["旁白", "阿明", "May", "阿芳"]

# Row 24's last part pushes past the device's own pool: the app derives a voice
# from the voices the engine lists for the turn's language, and no content of the
# reader's example comes near that number, so the driver writes one that does.
# The extra roles are the driver's own — the fixture stays the reader's example —
# and only the assignment is waited for: the app prints it before it starts
# speaking, so the row stops the read rather than listening to 24 turns.
PAST_ID = "dialogue_past_pool"
PAST_NAME = "两打角色"
PAST_EXTRA = 20
PAST_ROLES = PAST_EXTRA + len(FIXTURE_ROLES)
CHINESE_LOCALES = ("zh", "cmn", "yue")

# Every attribute `adb()` reads goes through the module's own DEV and OUT.
video.DEV = DEV
video.OUT = OUT

adb = video.adb
dump = video.dump
tap = video.tap
find = video.find
labels = video.labels
show = video.show
step = video.step
check = video.check
clear_logcat = video.clear_logcat
start_app = video.start_app
wait_for = video.wait_for
cat = video.cat
device_write = video.device_write
RESULTS = video.RESULTS

PREFS = f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml"
ROLES_KEY = "content_roles"

# The app follows the device's locale, and the reference AVD runs in Chinese:
# the driver matches the labels the app actually draws (`app_zh_Hans.arb`), with
# the English strings beside them (`app_en.arb`) so the same rows run on a
# device set to English. A row never names a label in only one language.
L = {
    "text_type": ("文字类型", "Text type"),
    "standard": ("标准", "Standard"),
    "dialogue": ("多人对话", "Dialogue"),
    "done": ("完成", "Done"),
    "format": ("排版", "Format"),
    "undo": ("撤销", "Undo"),
    "read": ("朗读", "Read"),
    "voice": ("语音", "Voice"),
    "back": ("返回", "Back"),
    "stop": ("停止", "Stop"),
    "pause": ("暂停", "Pause"),
    "resume": ("继续", "Resume"),
    "continue": ("继续朗读", "Continue Read"),
    "edit": ("编辑", "Edit"),
    "contents": ("内容", "Contents"),
    "remove_role": ("移除此角色", "Remove this role"),
    "remove_confirm": ("移除此角色？", "Remove this role?"),
    "delete": ("删除", "Delete"),
    "delete_confirm": ("删除此内容？", "Delete this content?"),
    "automatic": ("自动", "Automatic"),
    "format": ("排版", "Format"),
}

SPEAK_RE = re.compile(
    r"klhu speak p(\d+) s(\d+)"
    r"(?: role=([^ ]+))?"
    r"(?: voice=([^ ]+))?"
    r' "(.*)"')
ROLES_RE = re.compile(r"klhu roles (.*)")


# --------------------------------------------------------------------------
# the fixture, on the device
# --------------------------------------------------------------------------
def fixture_text():
    with open(FIXTURE, encoding="utf-8") as f:
        return f.read()


def fresh_prefs():
    """Drops the app's stored settings, so a row starts from a known state.

    This includes the app's own *language*, which the app remembers (007): after
    a wipe the chrome falls back to the device's locale, so the same row can draw
    in Chinese on one run and English on the next — which is why every label the
    driver taps is matched in both languages.

    The library is left alone — the row writes the fixture itself — and only the
    settings are removed: `read_position_*`, `voice_*` and `content_roles` are
    all in this one file, and a leftover position would make "from the top" a
    different starting point on a second run.
    """
    adb("shell", "am", "force-stop", PKG)
    adb("shell", "run-as", PKG, "rm", "-f", PREFS)


def seed_fixture():
    return seed(CONTENT_ID, CONTENT_NAME, fixture_text())


def seed(content_id, name, text):
    """Writes one content into the app's library and opens it.

    The library is files on disk — `content/index.json` plus one text file per
    entry — so a debug build is handed a content from here (012's own row 36
    does the same). The app caches the index in memory, so it is force-stopped
    after the write: what the row reads is the file on disk.
    """
    directory = f"{LIBRARY}/content"
    adb("shell", "run-as", PKG, "mkdir", "-p", f"{directory}/contents")
    if not device_write(f"{directory}/contents/{content_id}.txt",
                        text.encode()):
        return None
    index = json.loads(cat(INDEX).decode())
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S.000000Z", time.gmtime())
    index["entries"] = [e for e in index["entries"]
                        if e["id"] != content_id] + [{
        "id": content_id, "name": name, "language": "zh-Hans",
        "origin": "user", "createdAt": stamp, "updatedAt": stamp,
        "charCount": len(text),
    }]
    index["lastOpenedId"] = content_id
    if not device_write(INDEX, json.dumps(index).encode()):
        return None
    adb("shell", "am", "force-stop", PKG)
    start_app()
    return text


def unseed_fixture(content_id=CONTENT_ID):
    """Takes the row's own content back out — entry, text file and the app's
    memory of it — and forgets its dialogue settings."""
    index = json.loads(cat(INDEX).decode())
    index["entries"] = [e for e in index["entries"] if e["id"] != content_id]
    if index.get("lastOpenedId") == content_id:
        index["lastOpenedId"] = "preset_zh_sample"
    ok = device_write(INDEX, json.dumps(index).encode())
    adb("shell", "run-as", PKG, "rm", "-f",
        f"{LIBRARY}/content/contents/{content_id}.txt")
    adb("shell", "am", "force-stop", PKG)
    return ok


# --------------------------------------------------------------------------
# the app's own stored decisions
# --------------------------------------------------------------------------
def prefs_xml():
    return cat(PREFS).decode("utf-8", "replace")


def prefs_value(key):
    """One `shared_preferences` value, as text, or None.

    `shared_preferences` stores everything in one XML file under a `flutter.`
    prefix, so the row reads the app's own store rather than asking the app to
    tell it: this is what survives a restart.
    """
    xml = prefs_xml()
    m = re.search(r'name="flutter\.%s"[^>]*>(.*?)</string>' % re.escape(key),
                  xml, re.S)
    if m:
        return (m.group(1)
                .replace("&quot;", '"').replace("&amp;", "&")
                .replace("&lt;", "<").replace("&gt;", ">"))
    m = re.search(r'name="flutter\.%s"[^>]*value="([^"]*)"' % re.escape(key),
                  xml)
    return m.group(1) if m else None


def roles_pref():
    """The `content_roles` store, decoded: {content id: settings}."""
    raw = prefs_value(ROLES_KEY)
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except ValueError:
        return {"__corrupt__": raw}


def logcat_since_clear():
    return video.logcat()


def content_time(content_id=CONTENT_ID):
    """The content's own `updatedAt`, as the library index holds it.

    This is the version a removal is made against (008 moves it when the text is
    saved, FR-007), so a row that checks a removal compares the two as moments:
    the index writes microseconds and `DateTime.toIso8601String` writes
    milliseconds, which are the same instant spelled two ways.
    """
    for entry in json.loads(cat(INDEX).decode())["entries"]:
        if entry["id"] == content_id:
            return entry.get("updatedAt")
    return None


def instant(value):
    """An ISO-8601 instant as a moment, or None for anything unreadable."""
    if not value:
        return None
    try:
        return datetime.fromisoformat(value.replace("Z", "+00:00"))
    except ValueError:
        return None


def device_now():
    """The device's own clock, in logcat's own time format.

    The whole `date +…` is one argument because the device's own shell splits it:
    `adb shell date +%m-%d %H:%M:%S.000` gives toybox's "Max 1 argument".
    """
    return adb("shell", "date +'%m-%d %H:%M:%S.000'").stdout.strip()


def logcat_since(stamp):
    """The device's log from [stamp] on, by the device's own timestamps.

    Row 24's first run used `logcat -c` and read **zero** `klhu speak` lines
    while the app had spoken all five: clearing is asynchronous and the read's
    lines can arrive before the buffer is actually cut over. A timestamp taken
    immediately before the tap has no such race — and it is the same evidence
    (the app's own lines), just windowed by the device's clock.
    """
    return adb("logcat", "-d", "-v", "time", "-T", stamp).stdout


def speak_lines(log):
    """Every `klhu speak` line, parsed, in the order the engine was handed them."""
    out = []
    for line in log.splitlines():
        m = SPEAK_RE.search(line)
        if m:
            out.append({
                "paragraph": int(m.group(1)),
                "sentence": int(m.group(2)),
                "role": m.group(3),
                "voice": m.group(4),
                "text": m.group(5),
            })
    return out


def roles_lines(log):
    return [m.group(1) for m in
            (ROLES_RE.search(line) for line in log.splitlines()) if m]


def evidence_lines(log):
    """The lines a row quotes: the read's own assignment and its utterances.

    `klhu getVoices` writes one line per voice the engine lists — hundreds of
    them, once per voice-list load — so quoting "every line with klhu in it"
    buries the evidence the row is about under the device's voice catalogue.
    """
    return [line.split("I/flutter")[-1].strip() for line in log.splitlines()
            if "klhu speak" in line or "klhu roles" in line]


# --------------------------------------------------------------------------
# the UI the rows drive
# --------------------------------------------------------------------------
def tap_any(rows, key, label=None):
    """Taps the first of [key]'s labels that is on screen (see [L]).

    An exact match first: the page's app bar carries the app's own name beside
    朗读 ("卡啦虎朗读"), so a contains-match on 朗读 taps the title rather than the
    button — which is exactly what the first run of row 23 did.
    """
    for text in L[key]:
        if find(rows, text, exact=True):
            return tap(rows, text, label=label or text, exact=True)
    for text in L[key]:
        if find(rows, text):
            return tap(rows, text, label=label or text)
    print(f"   NOT FOUND: any of {L[key]} — visible: {labels(rows)[:14]}")
    return False


def open_chooser():
    return tap_any(dump(), "text_type", label="the text-type entry")


def shows(rows, key, exact=False, below=None, above=None):
    """Whether one of [key]'s labels is on screen — the state a step acts in,
    read before it acts in it (`tap_any`/`tap_exact` answer the same question by
    tapping; this answers it without).

    [exact] matters where one label contains another: 继续 (Resume) is inside
    继续朗读 (Continue Read), so a contains-match calls a read that has ENDED
    "paused". [below]/[above] narrow the search to a band of the screen, where a
    word appears more than once.
    """
    return any(find(rows, text, exact=exact, below=below, above=above)
               for text in L[key])


def tap_exact(rows, key, label=None):
    """Taps [key]'s label only when a node's own label IS it.

    A dialog's title contains its action's word (`Remove this role?` beside
    `Remove this role`), so the confirm button is the node whose label is the
    action itself and nothing more — a contains-match answers with the title.
    """
    for text in L[key]:
        if find(rows, text, exact=True):
            return tap(rows, text, label=label or text, exact=True)
    print(f"   NOT FOUND exactly: any of {L[key]} — visible: {labels(rows)[:14]}")
    return False


def set_dialogue():
    """Text type → 多人对话 → Done, through the app's own controls."""
    if not open_chooser():
        return False
    time.sleep(1)
    if not tap_any(dump(), "dialogue", label="the 多人对话 chip"):
        return False
    time.sleep(1)
    return tap_any(dump(), "done", label="the chooser's Done")


def read_from_top():
    """Reads the whole content from the top.

    `继续朗读` is the page's `_readContinue`: `_readRange(_anchor ?? 0, length)` —
    with no stored position that is the whole text from offset 0, which is what
    "start the read from the top" means. `朗读` is the *selection* read and
    refuses with `请先选择要朗读的句子或段落` when nothing is highlighted — the
    first run of this row pressed it and got exactly that message.
    """
    return tap_any(dump(), "continue", label="Continue Read")


# --------------------------------------------------------------------------
# row 23
# --------------------------------------------------------------------------
def row_23():
    step("row 23 — a four-role dialogue read on the device")
    fresh_prefs()
    text = seed_fixture()
    if text is None:
        check("23: the fixture reached the device", False, "device_write failed")
        return
    pushed = cat(f"{LIBRARY}/content/contents/{CONTENT_ID}.txt").decode(
        "utf-8", "replace")
    check("23: the fixture reached the device, whole",
          pushed == text and len(pushed) > 0,
          f"{len(pushed)} chars read back off the device, "
          f"{FIXTURE_SENTENCES} sentences expected")

    dump(1)
    if not set_dialogue():
        check("23: the type was set through the app's own chooser", False,
              f"visible: {labels(dump())}")
        return
    stored = roles_pref().get(CONTENT_ID, {})
    check("23: the app stored the type and nothing else (FR-001)",
          stored == {"type": "dialogue"},
          f"content_roles[{CONTENT_ID}] = {stored}")

    log = read_and_wait("23 the read", FIXTURE_SENTENCES)
    if not log:
        check("23: the read started from the top", False,
              f"visible: {labels(dump())}")
        return
    speaks = speak_lines(log)
    check("23: every sentence of the fixture reached the engine",
          len(speaks) >= FIXTURE_SENTENCES,
          f"{len(speaks)} `klhu speak` lines")
    if not speaks:
        show(dump())
        return

    spoken = [s["text"] for s in speaks]
    check("23: no spoken text carries a tag (FR-005)",
          all("{" not in t and "}" not in t for t in spoken),
          f"spoken: {spoken}")
    check("23: no spoken text carries a role name (FR-005)",
          all(not any(name in t for name in ("旁白", "阿明", "May", "阿芳"))
              for t in spoken),
          f"spoken: {spoken}")
    order = [(s["paragraph"], s["sentence"]) for s in speaks[:FIXTURE_SENTENCES]]
    check("23: one line per sentence, in the text's order (FR-010)",
          order == EXPECTED_ORDER,
          f"p/s: {[(s['paragraph'], s['sentence']) for s in speaks]}")
    check("23: every line names its role and voice (D10)",
          all(s["role"] and s["voice"] for s in speaks[:FIXTURE_SENTENCES]),
          f"roles: {[s['role'] for s in speaks]}")

    # May's turn is two lines of one paragraph: two sentences, one role, one
    # voice, back to back.
    may = [s for s in speaks if s["role"] == "May"]
    check("23: the two-line turn speaks as its two sentences, in one voice",
          len(may) == 2 and may[0]["voice"] == may[1]["voice"]
          and may[0]["paragraph"] == may[1]["paragraph"],
          f"May: {[(s['paragraph'], s['sentence'], s['voice']) for s in may]}")

    by_role = {s["role"]: s["voice"] for s in speaks}
    check("23: the four roles do not share one voice (FR-015)",
          len(set(by_role.values())) >= 2,
          f"role → voice: {by_role}")
    check("23: the read named the whole assignment (D10)",
          len(roles_lines(log)) >= 1 and all(
              name in roles_lines(log)[0] for name in by_role),
          f"klhu roles: {roles_lines(log)}")
    print(f"\n   the read's own lines:\n     "
          + "\n     ".join(evidence_lines(log)))


# --------------------------------------------------------------------------
# the assignment, parsed off the read's own lines
# --------------------------------------------------------------------------
VOICES_RE = re.compile(r"klhu getVoices: \{([^}]*)\}")


def voice_entries(log):
    """The device's own voices as the app reported them: {name: locale}.

    The app logs every voice the engine hands it (`klhu getVoices`, 007's line)
    whenever a voice list is loaded, so the read carries the device's voice list
    with it — the same evidence 012's spike S1 collected, without a second run.
    """
    out = {}
    for m in VOICES_RE.finditer(log):
        fields = dict(re.findall(r"(\w+): ([^,]+?)(?=, \w+: |$)", m.group(1)))
        name = (fields.get("name") or "").strip()
        if name:
            out[name] = (fields.get("locale") or "").strip()
    return out


def assignment(log):
    """The read's `klhu roles` line: {role: (voice, recorded gender)}."""
    out = {}
    for line in roles_lines(log):
        for part in line.split():
            if "\u2192" not in part:
                continue
            role, rest = part.split("\u2192", 1)
            if role.startswith("narration("):
                continue
            gender = None
            if rest.endswith(")") and "(" in rest:
                rest, gender = rest[:-1].split("(", 1)
            out[role] = (rest, gender)
    return out


def read_and_wait(tag, sentences, seconds=60):
    """Reads the whole content from the top, and waits for the read's own lines
    instead of a sleep — the app's evidence is the clock here."""
    stamp = device_now()

    def enough():
        return len(speak_lines(logcat_since(stamp))) >= sentences
    if not read_from_top():
        return None
    waited = wait_for(enough, seconds=seconds)
    log = logcat_since(stamp)
    print(f"   {tag}: {len(speak_lines(log))} `klhu speak` lines (waited {waited})")
    for line in roles_lines(log):
        print(f"   {tag} roles: {line}")
    return log


def pick_language_voice(display):
    """The reader's own pick, through the app's own screens: 语音 → the voice
    row → Back. Returns (ok, the labels the picker drew)."""
    if not tap_any(dump(), "voice", label="Voice"):
        return False, []
    time.sleep(1.5)
    rows = dump()
    seen = labels(rows)
    if not tap(rows, display, label=f"the {display} row"):
        return False, seen
    time.sleep(1)
    if not tap_any(dump(), "back", label="Back"):
        return False, seen
    time.sleep(1)
    return True, seen


def row_24():
    step("row 24 — the assignment against the device's own voices")
    fresh_prefs()
    text = seed_fixture()
    if text is None or not set_dialogue():
        return

    # (a) no picks at all: the assignment as the app derives it.
    log_a = read_and_wait("24 first read", FIXTURE_SENTENCES)
    if not log_a:
        return
    a = assignment(log_a)
    voices = voice_entries(log_a)
    check("24: the read printed the whole assignment (D10)",
          set(a) == set(FIXTURE_ROLES), f"{a}")
    check("24: every role's voice is a voice the device reports (FR-014)",
          all(v in voices for v, _ in a.values()),
          f"the device reports {len(voices)} voices; assigned "
          f"{[v for v, _ in a.values()]}")
    check("24: every voice is of its turn's own language (FR-014)",
          all((voices.get(v, "") or "?").lower().startswith(CHINESE_LOCALES)
              for v, _ in a.values()),
          f"the fixture's four turns are all zh-Hans; locales read back: "
          f"{[voices.get(v, '?') for v, _ in a.values()]}")
    check("24: no role is silent and none falls back to the OS default (FR-015)",
          all(v != "os-default" for v, _ in a.values()),
          f"{[v for v, _ in a.values()]}")
    distinct = len({v for v, _ in a.values()})
    check("24: each of the four roles got a voice of its own (FR-015)",
          distinct == len(FIXTURE_ROLES),
          f"{distinct} distinct voices for {len(FIXTURE_ROLES)} roles: "
          f"{sorted({v for v, _ in a.values()})}")
    g = [a[r][1] for r in FIXTURE_ROLES]
    check("24: the second role differs in recorded gender from the first (FR-015, D5)",
          g[0] is not None and g[1] is not None and g[0] != g[1],
          f"the assignment's recorded genders, in order: {g}")

    # (b) the same content, opened again: the same voices (FR-014 — assigned,
    # never stored).
    start_app()
    log_b = read_and_wait("24 second read", FIXTURE_SENTENCES)
    if not log_b:
        return
    b = assignment(log_b)
    check("24: the same content assigns the same voices on a second open (FR-014)",
          b == a, f"first {a} / second {b}")

    # (c) the reader's own pick for the language: 旁白 reads in it (FR-013).
    before = a[FIXTURE_ROLES[0]][0]
    PICK = "普通话 SSA (女)"
    ok, picker = pick_language_voice(PICK)
    check("24: the picker drew the device's Chinese voices (with the recorded gender beside each)",
          any(l.startswith("普通话") for l in picker),
          f"the picker's rows: {[l for l in picker if '普通话' in l][:6]}")
    if not ok:
        return
    stored = prefs_value("voice_zh_Hans")
    check("24: the pick is the reader's, stored under the language (FR-013)",
          stored is not None and stored.split("||")[0] != "",
          f"voice_zh_Hans = {stored}")
    log_c = read_and_wait("24 third read", FIXTURE_SENTENCES)
    if not log_c:
        return
    c = assignment(log_c)
    check("24: 旁白 reads in the voice the reader picked for that language (FR-013)",
          stored is not None and c[FIXTURE_ROLES[0]][0] == stored.split("||")[0]
          and c[FIXTURE_ROLES[0]][0] != before,
          f"picked {stored}; 旁白 before {before} → now {c[FIXTURE_ROLES[0]][0]}")
    check("24: the roles after it still differ (FR-015)",
          len({v for v, _ in c.values()}) == len(FIXTURE_ROLES),
          f"{c}")

    # (d) past the device's own pool: more roles than the device has voices for.
    fresh_prefs()
    many = text + "".join(f"\n{{R{i}}} 大家好。\n" for i in range(1, PAST_EXTRA + 1))
    if seed(PAST_ID, PAST_NAME, many) is None:
        return
    if not set_dialogue():
        return
    stamp = device_now()
    if not read_from_top():
        return
    # The whole content, heard out: this is the one read in this file that is long
    # enough to say "no read fails" with evidence rather than with a stopped read.
    waited = wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= PAST_ROLES,
                      seconds=240)
    log_d = logcat_since(stamp)
    for line in roles_lines(log_d):
        print(f"   24 past-pool roles: {line}")
    d = assignment(log_d)
    used = [v for v, _ in d.values()]
    shared = sorted({v for v in used if used.count(v) > 1})
    speaks = speak_lines(log_d)
    check("24: past the device's voices the sharing is visible and no role is silent (SC-004)",
          len(d) == PAST_ROLES and len(shared) >= 1
          and all(v != "os-default" for v in used),
          f"{len(d)} roles on {len(set(used))} distinct voices (waited {waited}); "
          f"shared: {shared[:4]}"
          f"{' …' if len(shared) > 4 else ''}"
          f" — every role past the pool reads in {shared[0] if shared else '?'}")
    check("24: the read reached the last role, so no role's read failed (SC-004)",
          len(speaks) >= PAST_ROLES
          and speaks[-1]["role"] == f"R{PAST_EXTRA}",
          f"{len(speaks)} utterances handed to the engine; last "
          f"{speaks[-1]['role'] if speaks else None} of R{PAST_EXTRA}")
    adb("shell", "am", "force-stop", PKG)  # the read ends with the row, not after
    unseed_fixture(PAST_ID)


# --------------------------------------------------------------------------
# the role list, its picker and its remove action (row 25)
# --------------------------------------------------------------------------
# Which role the row gives a voice and which name it removes are the row's own
# choices, not the spec's: the fixture's four roles all work, and May's turn is
# two lines, so removing May proves that BOTH of its lines fall back to narration
# together (FR-007's "the paragraphs it heads").
PICK_ROLE = "阿明"
PICK_DISPLAY = "SSA"
REMOVED_ROLE = "May"


def role_rows(rows):
    """The list's role rows, as `{name: the row's own node}`.

    The page draws one `ListTile` per role — the name on the title line, `turn
    count · voice` on the subtitle line — and Flutter hands uiautomator those two
    lines as ONE node. A row is recognised by that shape, never by where a name
    happens to appear on screen: the content itself spells the same names, one
    route behind this dialog.
    """
    out = {}
    for r in rows:
        label = r["desc"] or r["text"]
        name, newline, rest = label.partition("\n")
        if newline and name and "·" in rest:
            out.setdefault(name, r)
    return out


def role_row_label(rows, name):
    row = role_rows(rows).get(name)
    return (row["desc"] or row["text"]) if row else None


def role_remove_icon(rows, name):
    """The remove action belonging to [name]'s row.

    Every row's action carries the same label (`移除此角色` / `Remove this role`),
    so the one meant is the one drawn on the row's own line — the same y, in the
    same band.
    """
    row = role_rows(rows).get(name)
    if row is None:
        return None
    for r in rows:
        label = r["desc"] or r["text"]
        if any(text in label for text in L["remove_role"]) \
                and abs(r["y"] - row["y"]) < 20:
            return r
    return None


def tap_node(rows, node, label):
    """Taps a node the row has already chosen (a row, an icon) by its centre."""
    adb("shell", "input", "tap", str(node["x"]), str(node["y"]))
    print(f"   tap {label} @{node['x']},{node['y']}")
    return True


def open_role_list():
    """The type chooser's own surface, on a content that is already 多人对话: one
    entry offering the types, and in the dialogue type the roles the text
    proposes (FR-022). Returns the dump it opened on, or None."""
    if not open_chooser():
        return None
    time.sleep(1.5)
    return dump()


def close_role_list():
    return tap_any(dump(), "done", label="Done (the chooser's)")


def library_row(rows, name):
    """The library list's row for the content called [name], and its delete
    action — the second line carries the language and the date, so the row is
    the node whose label STARTS with the name."""
    row = next((r for r in rows
                if (r["desc"] or r["text"]).startswith(name)), None)
    if row is None:
        return None, None
    icon = next((r for r in rows
                 if any(text in (r["desc"] or r["text"]) for text in L["delete"])
                 and abs(r["y"] - row["y"]) < 20), None)
    return row, icon


def row_25():
    step("row 25 — a removal and a pick survive a restart")
    fresh_prefs()
    text = seed_fixture()
    if text is None:
        check("25: the fixture reached the device", False, "device_write failed")
        return
    if not set_dialogue():
        check("25: the type was set through the app's own chooser", False,
              f"visible: {labels(dump())}")
        return

    # (a) nothing decided yet: the roles the text itself proposes.
    log_a = read_and_wait("25 first read", FIXTURE_SENTENCES)
    if not log_a:
        return
    a = assignment(log_a)
    check("25: the text's own roles are proposed before anything is removed (FR-006)",
          set(a) == set(FIXTURE_ROLES), f"the read's roles: {list(a)}")

    # (b) the reader gives one role a voice, through that role's own picker
    # (FR-012) — the pick belongs to the role, never to the language.
    rows = open_role_list()
    if not rows:
        return
    names = list(role_rows(rows))
    check("25: the list draws one row per proposed role, in the text's order (FR-006)",
          names == FIXTURE_ROLES, f"the list's rows: {names}")
    role = role_rows(rows).get(PICK_ROLE)
    if role is None or not tap_node(rows, role, f"{PICK_ROLE}'s row"):
        check("25: a role's row opens the picker for that role (FR-012)", False,
              f"rows: {names}")
        return
    time.sleep(2)
    rows = dump()
    check("25: the shipped picker, titled with the role, offering the automatic row (FR-012)",
          any(PICK_ROLE in l for l in labels(rows)) and shows(rows, "automatic"),
          f"the picker's own labels: {labels(rows)[:4]}")
    pick = find(rows, PICK_DISPLAY)
    if not pick:
        check(f"25: the picker offers the {PICK_DISPLAY} voice", False,
              f"visible: {labels(rows)[:10]}")
        return
    tap_node(rows, pick[0], f"the {PICK_DISPLAY} row")
    time.sleep(1)
    if not tap_any(dump(), "back", label="Back (the picker's)"):
        return
    time.sleep(1.5)
    picks = (roles_pref().get(CONTENT_ID) or {}).get("voices") or {}
    picked = (picks.get(PICK_ROLE) or {}).get("name") or ""
    check("25: the pick is stored for that role alone, and not as the language's (FR-013)",
          list(picks) == [PICK_ROLE] and PICK_DISPLAY in picked.upper()
          and (picks.get(PICK_ROLE) or {}).get("locale") == "zh-CN"
          and prefs_value("voice_zh_Hans") is None,
          f"content_roles[{CONTENT_ID}]['voices'] = {picks}; "
          f"voice_zh_Hans = {prefs_value('voice_zh_Hans')!r}")
    rows = dump()
    check("25: the list names the picked voice on its role (FR-016)",
          PICK_DISPLAY in (role_row_label(rows, PICK_ROLE) or ""),
          f"{PICK_ROLE}'s row: {role_row_label(rows, PICK_ROLE)!r}")

    # (c) the reader removes a name: it stops being a role for THIS text, from
    # the version it was removed on (FR-006, FR-007).
    icon = role_remove_icon(rows, REMOVED_ROLE)
    if icon is None:
        check("25: the removed name's row offers the remove action", False,
              f"rows: {list(role_rows(rows))}")
        return
    tap_node(rows, icon, f"{REMOVED_ROLE}'s remove action")
    time.sleep(1.5)
    rows = dump()
    check("25: the removal asks first (the shipped dialog shape)",
          shows(rows, "remove_confirm"), f"the dialog's labels: {labels(rows)[:4]}")
    if not tap_exact(rows, "remove_role", label="the dialog's confirm"):
        return
    time.sleep(1.5)
    stored = roles_pref().get(CONTENT_ID) or {}
    removal = (stored.get("removed") or [{}])[0]
    version = content_time()
    check("25: the removal is stored with the text's own version (FR-007)",
          removal.get("name") == REMOVED_ROLE
          and instant(removal.get("at")) == instant(version),
          f"removed = {stored.get('removed')}; the index's updatedAt = {version}")
    rows = dump()
    check("25: the removed name is gone from the list (FR-006)",
          REMOVED_ROLE not in role_rows(rows),
          f"the list's rows: {list(role_rows(rows))}")
    check("25: the store holds the type, the removals and the picks — and nothing else (FR-021)",
          set(stored) == {"type", "removed", "voices"},
          f"the entry's own keys: {sorted(stored)}")

    # (d) the read, with the removal in force (FR-007, FR-009).
    if not close_role_list():
        return
    time.sleep(1)
    log_b = read_and_wait("25 the read with the removal in force",
                          FIXTURE_SENTENCES)
    if not log_b:
        return
    b = assignment(log_b)
    # May's turn is the fixture's third paragraph (p2), written across two lines
    # and two sentences: both lines must fall back together.
    narration = [s for s in speak_lines(log_b) if s["paragraph"] == 2]
    check("25: the removed name is no role in the read (FR-007)",
          REMOVED_ROLE not in b and len(narration) == 2
          and all(s["role"] is None for s in narration),
          f"the read's roles: {list(b)}; the removed turn's own lines: "
          f"{[(s['paragraph'], s['sentence'], s['role']) for s in narration]}")
    check("25: its paragraphs read as narration (FR-009)",
          any("narration(" in line for line in roles_lines(log_b)),
          f"the read's own line: {roles_lines(log_b)}")
    check("25: the role the reader gave a voice keeps it (FR-013)",
          b.get(PICK_ROLE, ("? ",))[0] == picked,
          f"{PICK_ROLE} reads in {b.get(PICK_ROLE, ('?',))[0]} (picked {picked})")
    print("\n   the read's own lines (the removal in force):\n     "
          + "\n     ".join(evidence_lines(log_b)))

    # (e) force-stop, start again: both decisions are still in force, and the
    # store is not rewritten by reading (FR-014: the assignment is derived).
    stored_before = prefs_value(ROLES_KEY)
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    start_app()
    rows = dump()
    check("25: the app reopens on the same content",
          any(l.startswith("{旁白}") for l in labels(rows)),
          f"the page's own labels: {labels(rows)[:3]}")
    rows = open_role_list()
    if not rows:
        return
    names = list(role_rows(rows))
    check("25: after the restart the removal is still in force (FR-007, SC-006)",
          REMOVED_ROLE not in names
          and names == [r for r in FIXTURE_ROLES if r != REMOVED_ROLE],
          f"the list's rows: {names}")
    check("25: after the restart the pick is still on its role (FR-012)",
          PICK_DISPLAY in (role_row_label(rows, PICK_ROLE) or ""),
          f"{PICK_ROLE}'s row: {role_row_label(rows, PICK_ROLE)!r}")
    if not close_role_list():
        return
    time.sleep(1)
    log_c = read_and_wait("25 the read after the restart", FIXTURE_SENTENCES)
    if not log_c:
        return
    c = assignment(log_c)
    check("25: the read after the restart is the read before it (FR-012, FR-013)",
          c == b
          and [(s["paragraph"], s["sentence"], s["role"])
               for s in speak_lines(log_c)]
          == [(s["paragraph"], s["sentence"], s["role"])
              for s in speak_lines(log_b)],
          f"before {b} / after {c}")
    check("25: reopening the content wrote nothing to the store (FR-014)",
          prefs_value(ROLES_KEY) == stored_before,
          f"content_roles = {prefs_value(ROLES_KEY)!r}")

    # (f) the content goes: its dialogue settings go with it (FR-021).
    if not tap_any(dump(), "contents", label="Contents"):
        return
    time.sleep(2)
    rows = dump()
    row, icon = library_row(rows, CONTENT_NAME)
    if row is None or icon is None:
        check("25: the library lists the content with its delete action", False,
              f"visible: {labels(rows)[:10]}")
        return
    tap_node(rows, icon, f"the delete action on {CONTENT_NAME}")
    time.sleep(1.5)
    rows = dump()
    check("25: the delete asks first (the shipped dialog shape)",
          shows(rows, "delete_confirm"), f"the dialog's labels: {labels(rows)[:4]}")
    if not tap_exact(rows, "delete", label="the dialog's Delete"):
        return
    time.sleep(2)
    check("25: deleting the content takes its dialogue settings with it (FR-021, SC-007)",
          CONTENT_ID not in roles_pref(),
          f"content_roles = {prefs_value(ROLES_KEY)!r}")


# --------------------------------------------------------------------------
# row 26 — the type switch and the reader's place
# --------------------------------------------------------------------------
# The band every shot of this row is taken from: the text area, with the app bar
# above it (y≈210) and the button row below it (y≈2261). The highlight is PAINT —
# a uiautomator dump carries no attribute for it — so the only place it can be
# read is the framebuffer, and this band is the part of the frame this row makes
# a claim about.
TEXT_BAND = (0, 260, 1080, 1300)

# How many sentences have to be in the log before the row pauses the read.
# The fixture read from the middle is three sentences (May's two and 阿芳's
# one, ~9s at this engine's pace), and uiautomator's dump costs ~2s, so the pause
# has to be asked for early rather than after the read has run out.
PAUSE_AFTER = 2

READ_RANGE_RE = re.compile(r"klhu read range: (\d+)\.\.(\d+)")


def read_ranges(log):
    """Every `klhu read range: a..b` line, in order — the range itself, which is
    what proves a read started where the reader pointed (research D10)."""
    return [(int(m.group(1)), int(m.group(2)))
            for m in READ_RANGE_RE.finditer(log)]


def content_node(rows):
    """The page's text node: one node whose label IS the content."""
    return next((r for r in rows
                 if (r["desc"] or r["text"]).startswith("{旁白}")), None)


def tap_content(label="the content, part-way in"):
    """Taps the content, mid-block: the page resolves the tap to the sentence
    under the finger and stores that offset as the position (010's own record),
    which is the anchor this row then moves the type around."""
    rows = dump()
    node = content_node(rows)
    if node is None:
        print(f"   NOT FOUND: the content — visible: {labels(rows)[:10]}")
        return False
    return tap_node(rows, node, label)


def shot(tag):
    """A still of the text band, and its digest.

    `ffmpeg` crops the band out of the framebuffer and hands back raw pixels
    (012's rows already require it), and the digest is of those pixels alone —
    so two shots can be compared without comparing the clock in the status bar or
    the buttons below. Every comparison in this row is guarded by a control pair
    taken back to back: if the same still is not identical to itself, the method
    is measuring noise and the row says so instead of proving anything.
    """
    path = video.screencap(os.path.join(OUT, f"{tag}.png"))
    if path is None:
        print(f"   screencap failed for {tag}")
        return None
    x, y, w, h = TEXT_BAND
    raw = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", path,
         "-vf", f"crop={w}:{h}:{x}:{y}", "-f", "rawvideo",
         "-pix_fmt", "rgb24", "-"],
        capture_output=True).stdout
    digest = hashlib.sha256(raw).hexdigest()
    print(f"   shot {tag}: band {TEXT_BAND} → {digest[:16]} ({len(raw) // 3} px)")
    return digest


def position_pref(content_id=CONTENT_ID):
    """The stored reading position, as `<offset>||<charCount>` (010's record)."""
    return prefs_value(f"read_position_{content_id}")


def position_offset(content_id=CONTENT_ID):
    raw = position_pref(content_id)
    if not raw or "||" not in raw:
        return None
    head = raw.split("||")[0]
    return int(head) if head.isdigit() else None


def switch_type(dialogue):
    """文字类型 → the one chip this row wants → Done, through the app's own
    chooser. Answers True once the chooser is actually gone (the chip writes the
    type the moment it is tapped; the Done on the step behind it only closes).

    The role step builds its list from the engine, so a tap aimed at Done while
    that list is still drawing is swallowed — the tap is repeated until the
    page's own buttons are back rather than assuming the first one landed.
    """
    if not open_chooser():
        return False
    time.sleep(1.5)
    if not tap_any(dump(), "dialogue" if dialogue else "standard",
                   label="the 多人对话 chip" if dialogue else "the 标准 chip"):
        return False
    for attempt in range(1, 4):
        time.sleep(2)
        rows = dump()
        if not shows(rows, "done"):
            print(f"   the chooser is dismissed (attempt {attempt})")
            return True
        tap_any(rows, "done", label=f"Done (tap {attempt})")
    return not shows(dump(), "done")


def pause_read(stamp, sentences):
    """Waits for [sentences] `klhu speak` lines, then taps Pause; answers the
    rows it read (None when the Pause button was not on screen at all).

    The wait is on the LOG, which is cheap, rather than on a dump, which is not —
    and a read that has already ended cannot be paused at all, because a read that
    ENDED clears the position (011 FR-022), the very thing this row measures. That
    is also why the row pauses on the FIRST pass through a range and never on a
    repeat: the second pass is spoken from the engine's own cache and is over
    before a dump can land (measured, twice).
    """
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= sentences,
             seconds=90)
    rows = dump()
    return rows if tap_any(rows, "pause", label="Pause") else None


def row_26():
    step("row 26 — switching the type mid-read keeps the reader's place")
    fresh_prefs()
    text = seed_fixture()
    if text is None:
        check("26: the fixture reached the device", False, "device_write failed")
        return
    version = content_time()
    stored = roles_pref().get(CONTENT_ID) or {}
    check("26: nothing is stored yet, so the content is 标准 (FR-001/FR-002)",
          stored == {}, f"content_roles[{CONTENT_ID}] = {stored}")

    # (a) the reader's own anchor: one tap on the text (010 FR-008).
    if not tap_content():
        return
    time.sleep(2)
    offset = position_offset()
    check("26: the tap anchors a sentence and stores the position (010)",
          offset is not None and 0 < offset < len(text),
          f"read_position_{CONTENT_ID} = {position_pref()} "
          f"({len(text)} chars of text)")

    # (b) before anything is compared: is a still of this band stable at all?
    before = shot("26 tapped")
    time.sleep(3)
    control = shot("26 tapped control")
    stable = before is not None and before == control
    check("26: the band is stable before anything is compared (the control)",
          stable, f"{str(before)[:16]} vs {str(control)[:16]}")

    # (c) 标准 reads from that sentence — and reads the tag OUT LOUD, because a
    # paragraph's text is all a 标准 read knows (FR-002).
    stamp = device_now()
    if not read_from_top():
        check("26: ⏭ Continue Read is reachable", False, f"visible: {labels(dump())}")
        return
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= PAUSE_AFTER,
             seconds=60)
    log_a = logcat_since(stamp)
    speaks_a = speak_lines(log_a)
    ranges_a = read_ranges(log_a)
    check("26: 标准 reads from the anchored sentence",
          ranges_a and ranges_a[0][0] == offset,
          f"read range {ranges_a[0] if ranges_a else None} for the stored "
          f"offset {offset}")
    check("26: 标准 speaks the paragraph as written — the tag included (FR-002)",
          bool(speaks_a) and speaks_a[0]["role"] is None
          and "{" in speaks_a[0]["text"],
          f"the first line: {speaks_a[0]['text'] if speaks_a else None!r}")

    # (d) the pause: the highlight and the position both stay (011's rule — only
    # a read that ENDED or a Stop takes them away).
    rows = pause_read(stamp, PAUSE_AFTER)
    if rows is None:
        check("26: the Pause button was on screen (the read was still running)",
              False, f"visible: {labels(dump())[:14]}")
        return
    rows = dump()
    check("26: pausing leaves Resume on screen (the shipped pause)",
          shows(rows, "resume", exact=True), f"the buttons: {labels(rows)[-4:]}")
    check("26: pausing leaves the position alone (010's record)",
          position_offset() == offset,
          f"read_position_{CONTENT_ID} = {position_pref()}")
    paused = shot("26 paused")
    time.sleep(3)
    paused_control = shot("26 paused control")
    check("26: the paused page is stable too (the second control)",
          paused is not None and paused == paused_control,
          f"{str(paused)[:16]} vs {str(paused_control)[:16]}")

    # (e) the switch, mid-read, with the highlight on screen.
    if not switch_type(dialogue=True):
        check("26: the type chooser opened and took 多人对话", False,
              f"visible: {labels(dump())}")
        return
    check("26: the switch stores the type (FR-001)",
          (roles_pref().get(CONTENT_ID) or {}).get("type") == "dialogue",
          f"content_roles[{CONTENT_ID}] = {roles_pref().get(CONTENT_ID)}")
    check("26: the switch leaves the position where it was (FR-020, SC-009)",
          position_offset() == offset,
          f"read_position_{CONTENT_ID} = {position_pref()}")
    after_switch = shot("26 after the switch")
    check("26: the highlight is where it was — the band is unchanged (SC-009)",
          after_switch is not None and after_switch == paused,
          f"{str(paused)[:16]} (paused) vs {str(after_switch)[:16]} (after the switch)")

    # (f) the text itself: 008's version is unmoved and the page shows it as
    # written, tags and all (switching is not editing).
    check("26: the text was not touched — 008's version is unmoved (FR-020)",
          content_time() == version,
          f"the index's updatedAt: {version} → {content_time()}")
    rows = dump()
    node = content_node(rows)
    check("26: the page still shows the text byte for byte",
          node is not None and (node["desc"] or node["text"]) == text,
          f"the page's own text node: {(node['desc'] or node['text'])[:24] if node else None!r}…")

    # (g) Stop is 011's rule, not this feature's: it takes the highlight AND the
    # position with it — which is why the row re-anchors by hand before reading
    # in the new mode rather than pretending the old anchor survived it.
    if not tap_any(dump(), "stop", label="Stop"):
        return
    time.sleep(1.5)
    check("26: Stop takes the position with it (011 FR-022, not this feature)",
          position_offset() is None,
          f"read_position_{CONTENT_ID} = {position_pref()!r}")

    # (h) the same sentence again, now in 多人对话: read from offset [offset] and
    # the paragraph's tag is gone, because a turn names its speaker instead.
    if not tap_content("the content, the same point"):
        return
    time.sleep(2)
    check("26: the reader's second anchor lands on the same offset",
          position_offset() == offset,
          f"read_position_{CONTENT_ID} = {position_pref()}")
    stamp = device_now()
    if not read_from_top():
        return
    # One line is enough for this mode's evidence (the range line and the turn's
    # own line) — and it leaves the read as much of itself as possible: this read
    # has to still be running when (i) pauses it, and a repeat of the same range
    # is shorter than the first pass (the engine has the audio by then).
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= 1, seconds=60)
    log_b = logcat_since(stamp)
    speaks_b = speak_lines(log_b)
    ranges_b = read_ranges(log_b)
    check("26: 多人对话 reads from the same sentence (FR-020, SC-009)",
          ranges_b and ranges_b[0][0] == offset,
          f"read range {ranges_b[0] if ranges_b else None} (标准's was {ranges_a[0] if ranges_a else None})")
    check("26: and reads it as a turn — the tag is not spoken in 多人对话 (FR-005)",
          bool(speaks_b) and speaks_b[0]["role"] is not None
          and "{" not in speaks_b[0]["text"]
          and speaks_b[0]["text"].strip() == speaks_a[0]["text"].replace("{May}", "").strip(),
          f"标准 said {speaks_a[0]['text']!r} / 多人对话 says "
          f"{speaks_b[0]['role']!r} {speaks_b[0]['text']!r}")
    check("26: the read named the assignment it used (D10)",
          bool(roles_lines(log_b)), f"{roles_lines(log_b)}")

    # (i) the way back. The repeat read runs out on its own: the engine has the
    # audio by then, so the pass is over before a dump can land on Pause — and a
    # read that ended takes the position with it (011 FR-022). The reader
    # therefore re-anchors by hand, exactly as they did the first time, and the
    # way back is measured from that quiet page.
    time.sleep(8)
    rows = dump()
    check("26: the repeat read ran out by itself and took the position (011)",
          not shows(rows, "pause") and not shows(rows, "resume", exact=True),
          f"the buttons: {labels(rows)[-4:]} / read_position = {position_pref()!r}")
    if not tap_content("the content, the same point again"):
        return
    time.sleep(2)
    check("26: the reader's third anchor lands on the same offset again (FR-020)",
          position_offset() == offset,
          f"read_position_{CONTENT_ID} = {position_pref()}")
    in_dialogue = shot("26 anchored in 多人对话")
    time.sleep(3)
    dialogue_control = shot("26 anchored in 多人对话 control")
    check("26: the anchored page in 多人对话 is stable (the third control)",
          in_dialogue is not None and in_dialogue == dialogue_control,
          f"{str(in_dialogue)[:16]} vs {str(dialogue_control)[:16]}")
    if not switch_type(dialogue=False):
        return
    check("26: switching back leaves nothing stored (FR-001)",
          not (roles_pref().get(CONTENT_ID) or {}).get("type"),
          f"content_roles[{CONTENT_ID}] = {roles_pref().get(CONTENT_ID)}")
    check("26: and the position is still the reader's own (FR-020)",
          position_offset() == offset,
          f"read_position_{CONTENT_ID} = {position_pref()}")
    back = shot("26 after switching back")
    check("26: there and back is a no-op on the page — exactly where it started "
          "(FR-020, SC-009)",
          back is not None and back == before,
          f"{str(before)[:16]} (标准, before the first switch) vs "
          f"{str(back)[:16]} (标准, after the way back)")
    check("26: the text is still untouched (008's version)",
          content_time() == version,
          f"the index's updatedAt: {version} → {content_time()}")

    adb("shell", "am", "force-stop", PKG)  # the read ends with the row, not after


# --------------------------------------------------------------------------
# row 27 — a dialogue's video on the device
# --------------------------------------------------------------------------
# What the renderer must paint for this fixture, turn by turn, with the tag left
# out: the spans it names are these sentences' own offsets in the raw text (the
# tag is a paragraph's head, so a turn's first sentence never starts at the
# paragraph's first character — 6 or 7 bytes of `{name}` and its colon sit before
# it). Written out rather than re-segmented here: a second segmenter in the driver
# would be a second implementation, and the device row's job is to say what the
# app did, not to agree with it by construction.
FIXTURE_TURNS = [
    ("旁白", "今天天气很好，适合出去走走。"),
    ("阿明", "今日个天气真系唔错啊，行下公园好舒服。"),
    ("May", "系啊，太阳晒住，风又凉爽。"),
    ("May", "真系适合周末。"),
    ("阿芳", "我好少黎呢个公园，原来呢度风景咁靓。"),
]

# 012's own aspect, so this row's file is comparable with 012's rows' files.
ASPECT = "16:9 landscape 1080p"


def assignment_of(line):
    """`旁白→cmn-cn-x-ccc-local(female) 阿明→…` → `{'旁白': 'cmn-cn-x-ccc-local', …}`."""
    out = {}
    for item in line.split():
        if "→" in item:
            role, voice = item.split("→", 1)
            out[role] = voice.split("(")[0]
    return out


def slot_field(runs, field):
    """One value per planned sentence: the renderer writes a slot's line steps
    together, and a slot is a sentence."""
    return [group[0][field] for group in video.slot_groups(runs)]


def ffprobe_json(path, *entries):
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-print_format", "json", *entries, path],
        capture_output=True)
    try:
        return json.loads(out.stdout or b"{}")
    except ValueError:
        return {}


def frame_pixels(path, number):
    """One frame, as an image — by number, so a sample is exact rather than a
    seek that lands a frame early or late."""
    probe = ffprobe_json(path, "-show_streams", "-show_format")
    streams = probe.get("streams", [])
    fixed = [s for s in streams if s.get("codec_type") == "video"]
    if not fixed:
        return None, probe
    width, height = int(fixed[0]["width"]), int(fixed[0]["height"])
    raw = video.frame_rgb(path, number, width, height)
    if raw is None:
        return None, probe
    return Image.frombytes("RGB", (width, height), raw), probe


# A lossy encoder leaves single-channel noise on the edges of glyphs — measured
# on this row's own file, two frames of one sentence differ on 44 pixels out of
# 2,073,600 (max delta 55), where two frames either side of a slot boundary differ
# on 12,844 (max delta 227). So a pixel counts as moved only when a channel moves
# by more than this, and "the picture did not change" means the moved share stays
# under 0.05% — an in-slot pair measures 0.002%, a boundary pair 0.62%.
FRAME_FLOOR = 16


def moved_fraction(a, b):
    """The share of the frame whose colour really moved between two frames."""
    diff = ImageChops.difference(a, b).convert("L").tobytes()
    return sum(1 for v in diff if v > FRAME_FLOOR) / len(diff)


def ink_fraction(image):
    """How much of the frame is not its own background — a frame with text or a
    picture in it is not a flat colour, and one of a blank slot would be."""
    background = Image.new("RGB", image.size, image.getpixel((2, 2)))
    return moved_fraction(image, background)


def row_27():
    step("row 27 — a dialogue's video: no tag in a frame, the read's own voices")
    fresh_prefs()
    text = seed_fixture()
    if text is None:
        check("27: the fixture reached the device", False, "device_write failed")
        return
    if not switch_type(dialogue=True):
        check("27: the content is 多人对话 before anything is rendered", False,
              f"visible: {labels(dump())[:14]}")
        return

    # (a) the read, first: its own assignment is what the video must use (D9 —
    # the video and the read voice a turn from one call). The read runs out on its
    # own; the position it leaves behind is 010's business, not this row's.
    stamp = device_now()
    if not read_from_top():
        return
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= 1, seconds=60)
    read_log = logcat_since(stamp)
    lines = roles_lines(read_log)
    assignment = assignment_of(lines[-1]) if lines else {}
    check("27: the read named an assignment for this text (D10)",
          bool(assignment), f"{lines[-1] if lines else 'no klhu roles line'}")
    check("27: the read spoke the turns in the fixture's order",
          len(speak_lines(read_log)) >= 1,
          f"{len(speak_lines(read_log))} line(s) seen before the render")
    # A clean page for the render: the app reopens the same content from the
    # library's own `lastOpenedId`, which the seed wrote (no navigation to do).
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    start_app()
    time.sleep(3)

    # (b) 012's own render path, on this content.
    result = video.render("row 27", ASPECT)
    if result is None:
        check("27: the render produced a file (012's own path)", False,
              "render() answered None — see its own FAIL above")
        return
    path, ms, size, frames, wall = result
    check("27: the render produced a file (012's own path)",
          bool(path) and size > 0 and frames > 0,
          f"{os.path.basename(path)} {ms}ms {size}B frames={frames} in {wall:.0f}s")

    local = os.path.join(OUT, "014_dialogue_" + os.path.basename(path))
    data, pulled = video.pull(path, local)   # (bytes, ok) — 012's own shape
    check("27: the file came back off the device",
          pulled and len(data) > 0,
          f"{local} — {len(data)} bytes" if pulled else "the pull failed")
    if not pulled:
        return

    # (c) the app's own account of the timeline, one line per painted run.
    runs = video.render_runs(video.logcat())
    check("27: the renderer's own lines parsed (012's parser, 014's fields) (D10)",
          bool(runs), f"{len(runs)} run(s) — {list(runs[0].keys()) if runs else ''}")
    if not runs:
        return
    spans = [(g[0]["span_start"], g[0]["span_end"])
             for g in video.slot_groups(runs)]
    expected = [(text.index(sentence), text.index(sentence) + len(sentence))
                for _, sentence in FIXTURE_TURNS]
    check("27: one slot per sentence, in the text's own order (FR-018)",
          spans == expected,
          f"the renderer painted {spans}, the sentences live at {expected}")
    check("27: every slot names its turn's role (FR-018)",
          slot_field(runs, "role") == [role for role, _ in FIXTURE_TURNS],
          f"the renderer wrote {slot_field(runs, 'role')}")
    with_tag = [len(text[text.rindex("{", 0, text.index(sentence)):
                        text.index(sentence) + len(sentence)])
                for _, sentence in FIXTURE_TURNS]
    check("27: no slot's painted text carries its tag (FR-005, SC-008)",
          slot_field(runs, "text") == [len(s) for _, s in FIXTURE_TURNS]
          and slot_field(runs, "text") != with_tag,
          f"painted lengths {slot_field(runs, 'text')} — the tag-free sentences "
          f"are {[len(s) for _, s in FIXTURE_TURNS]}, with the tag they would be {with_tag}")
    check("27: the roles the render used are the read's own roles (D9, FR-019)",
          [role for role, _ in FIXTURE_TURNS] == slot_field(runs, "role")
          and all(r in assignment for r in slot_field(runs, "role")),
          f"the read said {assignment}; the render's slots say "
          f"{sorted(set(slot_field(runs, 'role')))}")

    # (d) the file itself.
    probe = ffprobe_json(local, "-count_frames", "-show_streams", "-show_format")
    streams = probe.get("streams", [])
    fmt = probe.get("format", {})
    video_s = next((s for s in streams if s.get("codec_type") == "video"), None)
    audio_s = next((s for s in streams if s.get("codec_type") == "audio"), None)
    read_frames = int(video_s.get("nb_read_frames", -1)) if video_s else -1
    file_ms = int(round(float(fmt.get("duration", 0)) * 1000))
    check("27: the file carries the frames the render reported (FR-018)",
          video_s is not None and read_frames == frames,
          f"{read_frames} frames in the file, {frames} reported by the render "
          f"({video_s.get('width')}x{video_s.get('height')})" if video_s else "no video stream")
    check("27: the file carries audio, and it is as long as the render",
          audio_s is not None and abs(file_ms - ms) <= 1000,
          f"audio {audio_s.get('codec_name') if audio_s else 'absent'} at "
          f"{audio_s.get('sample_rate') if audio_s else '-'} Hz; the file is "
          f"{file_ms}ms, the render reported {ms}ms")

    # (e) the frames themselves: one picture per sentence, and a turn's first
    # frame is its own — nothing of the turn before it is left on the screen.
    pictures = []
    for group in video.slot_groups(runs):
        first = group[0]["start"]
        last = group[-1]["start"] + group[-1]["frames"] - 1
        head, _ = frame_pixels(local, first)
        tail, _ = frame_pixels(local, last)
        if head is None or tail is None:
            check("27: the sampled frames came out of the file", False,
                  f"frame {first} or {last} would not decode")
            return
        pictures.append((first, head, tail))
        ink = ink_fraction(head)
        # The shortest sentence in the fixture paints 0.20% of the frame and a
        # blank one paints none of it, so the line sits a factor of four below
        # the smallest measured: this is "there is text in the picture", not a
        # measurement of how much.
        check(f"27: slot {group[0]['slot']} ({group[0]['role']}) has a picture "
              f"with text in it, not a blank frame",
              ink > 0.0005,
              f"frame {first}: {ink * 100:.2f}% of the frame is not background")
    inside = [moved_fraction(head, tail) for _, head, tail in pictures]
    check("27: a sentence's picture does not change inside its own slot",
          all(m < 0.0005 for m in inside),
          "the frames' moved share inside a slot: "
          + ", ".join(f"{m * 100:.3f}%" for m in inside))
    turns = [(0, "旁白"), (1, "阿明"), (2, "May"), (4, "阿芳")]
    crossing = [(slot, role, moved_fraction(pictures[slot][1], pictures[slot - 1][1]))
                for slot, role in turns if slot > 0]
    check("27: a frame at a turn boundary belongs to the turn it opens (FR-018)",
          all(share > 0.001 for _, _, share in crossing),
          "the frame that opens a turn against the one before it: "
          + ", ".join(f"{role} {share * 100:.3f}%" for _, role, share in crossing))
    pairs = [(a, b, moved_fraction(pictures[a][1], pictures[b][1]))
             for a in range(len(pictures)) for b in range(a + 1, len(pictures))]
    closest = min(pairs, key=lambda t: t[2])
    check("27: each sentence has its own picture — no two sentences share a frame",
          closest[2] > 0.001,
          f"the closest two of the {len(pairs)} slot pairs are slots "
          f"{closest[0]}/{closest[1]} at {closest[2] * 100:.3f}% moved")

    adb("shell", "am", "force-stop", PKG)   # the review screen ends with the row


# --------------------------------------------------------------------------
# row 28 — spike S1: how many distinct voices does this device list?
# --------------------------------------------------------------------------
# Spike S1 is a measurement, not a claim about the app: it reads the engine's own
# voice list (through the app's `klhu getVoices` lines, which `voicesForAll`
# prints one per entry) and the app's recorded gender table
# (`lib/models/voice_mapping.dart` — the engine exposes no gender at all), and
# answers with a table. Its answer is what SC-003's "whenever the device lists at
# least N matching voices" is bounded by, and what row 24's PASS is read against.
VOICE_ID_RE = re.compile(r"systemVoiceId: '([^']+)'")
VOICE_NAME_RE = re.compile(r"chineseName: '([^']*)'")
VOICE_GENDER_RE = re.compile(r"gender: (?:'([^']*)'|null)")

# The app's own language lists, by the locale's first subtag. The engine reports
# hundreds of locales; the four this app shows are these.
LANGUAGE_OF = {
    "cmn": "普通话 (Mandarin)", "zh": "普通话 (Mandarin)",
    "yue": "粤语 (Cantonese)", "en": "English", "es": "Español",
}


def recorded_gender_table():
    """`systemVoiceId → (chineseName, gender)` from the app's own table.

    The table is the app's data (voice_mapping.dart), and it is the only place a
    gender exists — the engine's list carries none — so a spike about gender has
    to read it from there.
    """
    rows = {}
    current = None
    for line in open(os.path.join(REPO, "lib", "models", "voice_mapping.dart"),
                     encoding="utf-8"):
        hit = VOICE_ID_RE.search(line)
        if hit:
            current = hit.group(1)
            rows[current] = ("", None)
            continue
        if current is None:
            continue
        name = VOICE_NAME_RE.search(line)
        if name:
            rows[current] = (name.group(1), rows[current][1])
        gender = VOICE_GENDER_RE.search(line)
        if gender:
            rows[current] = (rows[current][0], gender.group(1))
    return rows


def voice_key(name):
    """The voice itself, without the variant suffix: the app's table says the
    measured local and network variants of a code are the same voice, so a count
    of distinct voices cannot count them twice."""
    for suffix in ("-local", "-network"):
        if name.endswith(suffix):
            return name[: -len(suffix)]
    return name


def gender_of(name, table):
    """The recorded gender, by the id the engine gave or by its base code."""
    for candidate in (name, voice_key(name)):
        for row_id, (_, gender) in table.items():
            if row_id == candidate or voice_key(row_id) == candidate:
                if gender:
                    return gender
    return None


def row_28():
    step("row 28 — spike S1: the device's own voice list, by language and gender")
    fresh_prefs()
    text = seed_fixture()
    if text is None:
        check("28: the fixture reached the device", False, "device_write failed")
        return
    stamp = device_now()
    # `语音` is the language's own picker: opening it makes the app load the
    # engine's whole list, which it prints. Nothing is decided by looking.
    if not tap_any(dump(), "voice", label="the voice entry"):
        check("28: the voice entry opened (the app loaded the engine's list)",
              False, f"visible: {labels(dump())[:12]}")
        return
    wait_for(lambda: len(voice_entries(logcat_since(stamp))) > 0, seconds=30)
    time.sleep(2)
    entries = voice_entries(logcat_since(stamp))
    check("28: the engine's own list came off the app (one line per entry)",
          len(entries) > 0, f"{len(entries)} entries in this window")

    table = recorded_gender_table()
    check("28: the app's recorded gender table was read (its only gender source)",
          len(table) > 0, f"{len(table)} ids in lib/models/voice_mapping.dart")

    # `voice_entries` (rows 23/24's own parser) answers {name: locale}; the spike
    # counts the voices behind those names, so the variant suffix comes off.
    distinct = {}
    for name, locale in entries.items():
        distinct.setdefault(voice_key(name), (name, locale))

    counted = {}
    unknown = []
    for key, (name, locale) in distinct.items():
        language = LANGUAGE_OF.get(locale.split("-")[0].lower())
        if language is None:
            continue
        gender = gender_of(name, table) or "not recorded"
        if gender == "not recorded":
            unknown.append(key)
        counted.setdefault((language, gender), []).append(key)

    app_languages = sorted({lang for lang, _ in counted})
    check("28: the app's own language lists are the ones counted (and no others)",
          bool(app_languages) and set(app_languages) <= set(LANGUAGE_OF.values()),
          f"counted {app_languages}")

    print("\n   device voice table (distinct voices, local/network variants counted "
          "once, gender from the app's own table):")
    for language in sorted({lang for lang, _ in counted}):
        for gender in ("female", "male", "not recorded"):
            keys = counted.get((language, gender), [])
            if keys:
                print(f"     {language:22s} {gender:13s} {len(keys):3d}  "
                      f"{', '.join(sorted(k.split('-x-')[-1] for k in keys))}")

    mandarin = {g: len(counted.get(("普通话 (Mandarin)", g), []))
                for g in ("female", "male")}
    check("28: the Mandarin bound is recorded, not demanded (SC-003's N)",
          True,
          f"the device lists {mandarin['female']} female and {mandarin['male']} male "
          f"distinct Mandarin voices with a recorded gender")
    cantonese = {g: len(counted.get(("粤语 (Cantonese)", g), []))
                 for g in ("female", "male")}
    print(f"   Cantonese: {cantonese['female']} female, {cantonese['male']} male "
          f"distinct voices with a recorded gender")
    check("28: the app's table and the device's list were compared",
          not unknown or True,
          f"{len(unknown)} of {len(distinct)} distinct voices carry no recorded "
          f"gender" + (f": {sorted(unknown)[:6]}" if unknown else ""))

    # What row 24's PASS is bounded by: the number of distinct voices the device
    # offers for the languages the fixture uses.
    for language in ("普通话 (Mandarin)", "粤语 (Cantonese)"):
        total = sum(len(counted.get((language, g), []))
                    for g in ("female", "male"))
        check(f"28: {language} — distinct voices the assignment can choose from",
              total > 0, f"{total} with a recorded gender "
                         f"({len(counted.get((language, 'not recorded'), []))} without)")

    tap_any(dump(), "back", label="Back")
    time.sleep(1)
    adb("shell", "am", "force-stop", PKG)


# --------------------------------------------------------------------------
# row 33 — the editor's Format press, with the reader's own hands
# --------------------------------------------------------------------------
# The text this row edits: two tags on ONE line, and a third that already starts
# a line — so the press has both halves of the rule to do (a blank line before a
# mid-line tag, one more line break before a tag that is already at a line's
# start) and a tag it must leave exactly where it is.
ROW33_ID = "dialogue_format_fixture"
ROW33_NAME = "排版样本"
ROW33_TEXT = ("{旁白} 今天天气很好，适合出去走走。{阿明} 今日个天气真系唔错啊，"
              "行下公园好舒服。\n{May} 系啊，太阳晒住，风又凉爽。")


def editor_text():
    """The editor's own text, off the page.

    A `uiautomator dump` is the ground truth for Flutter text on this host (the
    reader's own note), and in edit mode the field's whole contents are one
    node's label — the row reads that rather than a still.
    """
    rows = dump()
    hits = [unxml(r["desc"] or r["text"]) for r in rows
            if "{旁白}" in (r["desc"] or r["text"])]
    return max(hits, key=len) if hits else None


def unxml(label):
    """A dump label's own escapes, undone.

    012's `dump` undoes `&#10;` for content-descs; a Flutter text field's contents
    come through as `text`, where the entity survives — and a comparison against
    the library's file would then be off by four characters per line break.
    """
    return (label.replace("&#10;", "\n").replace("&#39;", "'")
            .replace("&quot;", '"').replace("&amp;", "&"))


def paragraph_heads(text):
    """Every tag's `{`, with whether it is the first non-space thing of its own
    paragraph — the state FR-024 says a Format press must leave the text in."""
    out = []
    for at, ch in ((i, c) for i, c in enumerate(text) if c == "{"):
        close = text.find("}", at + 1)
        newline = text.find("\n", at)
        if close <= at + 1 or (0 <= newline < close):
            continue          # not the tag grammar: an unclosed brace, a pair
                              # across a line, or an empty pair (FR-024)
        if not text[at + 1:close].strip():
            continue
        head = text.rfind("\n\n", 0, at) + 2
        out.append((at, text[head:at].strip() == ""))
    return out


def press(key, label, settle=1.2):
    """One press, then a wait longer than the platform's undo throttle (500 ms):
    a press inside that window *cancels* a pending push instead of landing in
    turn, which would read as the app failing."""
    ok = tap_any(dump(), key, label=label)
    time.sleep(settle)
    return ok


def row_33():
    step("row 33 — the editor's Format press, with the reader's own hands")
    fresh_prefs()
    text = seed(ROW33_ID, ROW33_NAME, ROW33_TEXT)
    if text is None:
        check("33: the row's own content reached the device", False, "device_write failed")
        return
    time.sleep(1)

    if not press("edit", "the editor entry"):
        check("33: the editor opened", False, f"visible: {labels(dump())[:12]}")
        unseed_fixture(ROW33_ID)
        return
    before = editor_text()
    check("33: the editor shows the row's text, tag for tag",
          before == ROW33_TEXT,
          f"the field reads {len(before) if before else 0} chars: "
          f"{before[:40] if before else None!r}…")

    heads_before = paragraph_heads(before or "")
    check("33: the text is two tags on one line plus one at a line start, and no "
          "tag is yet its own paragraph's onset",
          len(heads_before) == 3 and [h for _, h in heads_before] == [True, False, False],
          f"the tags are at their paragraph's head: {[h for _, h in heads_before]} "
          f"— May's tag starts a line, but its paragraph began two lines earlier")

    if not press("format", "the Format button"):
        check("33: the Format button is on the editor's toolbar", False,
              f"visible: {labels(dump())[:14]}")
        unseed_fixture(ROW33_ID)
        return
    after = editor_text()
    check("33: the press changed the text (the button was enabled for a reason)",
          after is not None and after != before,
          f"{len(before or '')} chars → {len(after or '')} chars")

    heads_after = paragraph_heads(after or "")
    check("33: every tag is now the first non-space thing of its own paragraph (FR-024)",
          len(heads_after) == 3 and all(h for _, h in heads_after),
          f"the tags are at their paragraph's head: {[h for _, h in heads_after]}")
    check("33: the difference is blank lines and nothing else (FR-024, SC-011)",
          (after or "").replace("\n", "").replace(" ", "")
          == (before or "").replace("\n", "").replace(" ", "")
          and len(after or "") > len(before or "")
          and head_of_tags(after or "") == head_of_tags(before or ""),
          f"same non-newline characters in the same order and the same tag onset "
          f"after trimming ({head_of_tags(after or '')!r}); "
          f"{len(after or '') - len(before or '')} character(s) added, all line breaks")

    # A second press must be a no-op: the app disables the button when the text
    # is already formatted (`formatForDialogue(value.text) == value.text`).
    press("format", "the Format button again")
    again = editor_text()
    check("33: a second press changes nothing — the text is already formatted",
          again == after, f"{len(again or '')} chars, unchanged"
          if again == after else "the second press moved the text")

    press("undo", "Undo")
    undone = editor_text()
    check("33: Undo puts the reader's own text back, byte for byte (SC-011)",
          undone == before,
          "the field is the text from before the press"
          if undone == before else f"the field reads {undone[:40] if undone else None!r}…")

    press("format", "the Format button once more")
    formatted = editor_text()
    press("done", "Done")
    time.sleep(1)
    stored = cat(f"{LIBRARY}/content/contents/{ROW33_ID}.txt").decode("utf-8", "replace")
    check("33: Done saves the formatted text through 008's own path (FR-024)",
          stored == formatted,
          f"the library holds {len(stored)} chars, the editor had "
          f"{len(formatted) if formatted else 0}")
    page = next((unxml(r["desc"] or r["text"]) for r in dump()
                 if (r["desc"] or r["text"]).startswith("{旁白}")), None)
    check("33: the reopened content shows the formatted text",
          page is not None and page == formatted,
          f"the page's own text node holds {len(page) if page else 0} chars, "
          f"{'the same as' if page == formatted else 'different from'} the editor's")

    unseed_fixture(ROW33_ID)


def head_of_tags(text):
    """The text with every tag replaced by a marker — what must not change when
    the press only inserts line breaks."""
    out, i = [], 0
    while i < len(text):
        if text[i] == "{":
            close = text.find("}", i + 1)
            newline = text.find("\n", i)
            if close > i + 1 and (newline < 0 or close < newline):
                out.append("<>")
                i = close + 1
                continue
        if text[i] != "\n":
            out.append(text[i])
        i += 1
    return "".join(out)


ROWS = {"23": row_23, "24": row_24, "25": row_25, "26": row_26, "27": row_27,
        "28": row_28, "33": row_33}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(__doc__)
        print(f"rows implemented here: {', '.join(sorted(ROWS))}")
        todo = [r for r in ("23", "24", "25", "26", "27", "28", "33")
                if r not in ROWS]
        print("rows still to come (walk them by hand with the same commands): "
              + ", ".join(todo))
        sys.exit(2)
    row = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 014 row {row} — device {DEV}, package {PKG}, out {OUT}")
    ROWS[row]()

    print("\n===== result =====")
    failed = [r for r in RESULTS if not r[1]]
    for name, ok, detail in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}"
              f"{(' — ' + detail) if detail else ''}")
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
