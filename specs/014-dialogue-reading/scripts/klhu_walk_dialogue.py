#!/usr/bin/env python3
"""klhu device walk — 014 quickstart rows 23-28 and 33.

Row 23: a four-role dialogue on the device — the fixture read from the top, with
        logcat's `klhu speak` lines as the witness: the turns' contents in order,
        no tag and no role name in any spoken text, one line per sentence, each
        in its role's voice, the whole assignment named by the read's own
        `klhu roles` line.

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

A row is implemented here in the pass that walks it; `main` names the rows it
does not have yet rather than dispatching into a stub.
"""
import json
import os
import re
import sys
import time

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
    "read": ("朗读", "Read"),
    "voice": ("语音", "Voice"),
    "back": ("返回", "Back"),
    "stop": ("停止", "Stop"),
    "continue": ("继续朗读", "Continue Read"),
    "edit": ("编辑", "Edit"),
    "remove_role": ("移除此角色", "Remove this role"),
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
          + "\n     ".join(l for l in log.splitlines() if "klhu " in l))


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


ROWS = {"23": row_23, "24": row_24}


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
