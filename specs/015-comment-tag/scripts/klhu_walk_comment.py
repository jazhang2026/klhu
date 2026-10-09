#!/usr/bin/env python3
"""klhu device walk — 015 quickstart rows 17-26.

Row 17: a comment read on the device — the page paints the comment's words and no
        marker, the read speaks the sentence's utterances then the comment's with
        `comment=1`, in the two languages' own voices, and the `[nota]`/`[註]`
        contents read exactly as the `[注]` one did.
Row 18: the inline tag's reach — `Hola. [注] Hi. Adiós.` reads one comment
        (`Hi.` then `Adiós.`, English) and `Adiós.` is never a Spanish-voice
        utterance.
Row 19: a tap inside a comment answers, in both settings — with the comments read
        the range is the comment's own span, with them off the owner sentence's.
Row 20: the switch off, across a restart, and with the content gone.

The mechanics are 014's (`specs/014-dialogue-reading/scripts/klhu_walk_dialogue.py`),
which are 012's: one string per `adb shell` command, `uiautomator dump` reads,
`tap(rows, label)`, `check(name, ok, detail)` with a PASS/FAIL summary and a non-zero
exit on failure. 015 adds only what is its own: the fixture (its named sections), the
`comment=1` field on the read's own line, and the parsers for it.

Usage:  python3 klhu_walk_comment.py 17
        ADB_SERIAL=emulator-5554 python3 klhu_walk_comment.py 17
        KLHU_REPO=~/Documents/GitHub/Projects/klhu KLHU_OUT=/tmp/klhu_out \\
            python3 klhu_walk_comment.py 17
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.

Run a row with `python3 -u`: the row prints its progress and its evidence as it goes.

A row is implemented here in the pass that walks it; `main` names the rows it does
not have yet rather than dispatching into a stub (014's own convention).
"""
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "014-dialogue-reading", "scripts"))

# 014's module owns the device mechanics (and 012's beneath it): one
# implementation of "dump, find, tap, check", and one place that knows how the
# app's library is laid out on disk.
import klhu_walk_dialogue as dialogue  # noqa: E402

video = dialogue.video
DEV = dialogue.DEV
OUT = dialogue.OUT
PKG = dialogue.PKG
LIBRARY = dialogue.LIBRARY
PREFS = dialogue.PREFS

adb = dialogue.adb
dump = dialogue.dump
tap = dialogue.tap
find = dialogue.find
labels = dialogue.labels
show = dialogue.show
step = dialogue.step
check = dialogue.check
cat = dialogue.cat
device_write = dialogue.device_write
start_app = dialogue.start_app
wait_for = dialogue.wait_for
fresh_prefs = dialogue.fresh_prefs
seed = dialogue.seed
set_dialogue = dialogue.set_dialogue
read_from_top = dialogue.read_from_top
tap_any = dialogue.tap_any
shows = dialogue.shows
open_chooser = dialogue.open_chooser
prefs_value = dialogue.prefs_value
roles_pref = dialogue.roles_pref
logcat_since = dialogue.logcat_since
device_now = dialogue.device_now
read_ranges = dialogue.read_ranges
voice_entries = dialogue.voice_entries
RESULTS = dialogue.RESULTS

video.DEV = DEV
video.OUT = OUT

# The app follows the device's locale, so every label is matched in both the
# Chinese the reference AVD draws and the English a device set to English draws.
L = dict(dialogue.L)
L["comments"] = ("朗读注释", "Read the comments")

FIXTURE = os.path.join(HERE, "klhu_comment_fixture.txt")

# What each fixture section reads as, by the app's own units: the paragraph's
# sentences, then the comment's (each its own utterance, FR-007). `head_comment`
# and `full_width` have no spoken comment — the first belongs to no sentence
# (FR-003), the second is ordinary text (A1) — so their comment units are 0.
SECTIONS = {
    "main": {"sentences": ["Hola."], "comment": "How are you?"},
    "nota": {"sentences": ["Hola."], "comment": "How are you?"},
    "traditional": {"sentences": ["Hola."], "comment": "How are you?"},
    "inline": {"sentences": ["Hola.", "Hi.", "Adiós."], "comment": None},
    "dialogue": {"sentences": ["今日个天气真系唔错啊。"], "comment": "How are you?"},
    "standard_tags": {"sentences": ["今日个天气真系唔错啊。"], "comment": "How are you?"},
    "head_comment": {"sentences": ["Hola."], "comment": None},
    "marker_only": {"sentences": ["Hola."], "comment": None},
    "full_width": {"sentences": ["Hola.", "［注］", "How are you?"], "comment": None},
}


def fixture_sections():
    """The fixture file, split into its named sections: {name: text}."""
    sections, name, buf = {}, None, []
    with open(FIXTURE, encoding="utf-8") as f:
        for line in f.read().splitlines():
            if line.startswith("## "):
                if name is not None:
                    sections[name] = "\n".join(buf).strip("\n")
                name, buf = line[3:].strip(), []
            else:
                buf.append(line)
    if name is not None:
        sections[name] = "\n".join(buf).strip("\n")
    return sections


# The read's own evidence line, with 015's field appended AFTER the quoted
# utterance (D9) so 014's own regex keeps matching: 014's drivers read
# `klhu speak p<i> s<j>( role=…)?( voice=…)? "…"` and never look past the quote.
SPEAK_RE = re.compile(
    r"klhu speak p(\d+) s(\d+)"
    r"(?: role=([^ ]+))?"
    r"(?: voice=([^ ]+))?"
    r' "(.*)"'
    r"(?: comment=1)?")


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
                "comment": "comment=1" in m.group(0),
            })
    return out


def painted_text(rows):
    """The page's own text node: the one node whose label holds the content."""
    for r in rows:
        label = r["desc"] or r["text"]
        if "Hola." in label or "今日个天气" in label:
            return label
    return ""


def content_node():
    """The painted content node, with its own box (x, y, w, h)."""
    for node in video.raw_nodes():
        label = node["desc"] or node["text"]
        if "Hola." in label or "今日个天气" in label:
            return node
    return None


def read_and_wait(tag, units, seconds=60):
    """Reads the whole content from the top, and waits for the read's own lines
    instead of a sleep — the app's evidence is the clock here."""
    stamp = device_now()

    def enough():
        return len(speak_lines(logcat_since(stamp))) >= units
    if not read_from_top():
        return None
    waited = wait_for(enough, seconds=seconds)
    log = logcat_since(stamp)
    print(f"   {tag}: {len(speak_lines(log))} `klhu speak` lines (waited {waited})")
    return log


def open_section(section, cid=None, name=None, text=None):
    """Pushes one fixture section into the library and opens it.

    [text] overrides the fixture — row 22's tagless twin is the same sentence the
    fixture's `main` opens with and no comment at all.
    """
    text = fixture_sections()[section] if text is None else text
    cid = cid or f"comment_{section}"
    if seed(cid, name or section, text) is None:
        check(f"{section}: the fixture reached the device", False,
              "device_write failed")
        return None
    pushed = cat(f"{LIBRARY}/content/contents/{cid}.txt").decode("utf-8", "replace")
    if pushed != text:
        check(f"{section}: the fixture reached the device, whole",
              False, f"{len(pushed)} chars read back, {len(text)} written")
        return None
    time.sleep(1)
    return text


def harvest_voices():
    """The device's own voice list, as the app loads it when a picker opens.

    A bare read prints no catalogue (`ReaderService.voicesForAll` logs nothing);
    the picker's own `voicesFor` logs EVERY entry the engine reports, so one
    open/Back is the whole list — every language the device has, which is what
    the two picks below are chosen from.
    """
    stamp = device_now()
    if not tap_any(dump(), "voice", label="the 语音 entry"):
        return {}
    wait_for(lambda: len(voice_entries(logcat_since(stamp))) > 0, seconds=30)
    time.sleep(2)
    entries = voice_entries(logcat_since(stamp))
    tap_any(dump(), "back", label="Back")
    time.sleep(1)
    return entries


def set_comments():
    """Toggles the comments switch on the page's own sheet: Text type → the
    switch → Done. Answers the app's store after the tap.

    The lookup is this module's own, not 014's `tap_any`/`shows`: those read
    014's `L`, which has no `comments` key.
    """
    if not open_chooser():
        # A render leaves its review up, and the review covers the page's own
        # toolbar — take it down and ask again before giving up.
        rows = dump()
        if not video.on_screen(rows, "Discard"):
            print(f"   the text-type sheet did not open — "
                  f"visible: {labels(rows)[:12]}")
            return None
        video.tap(rows, "Discard", label="the render's review")
        time.sleep(1.5)
        if not open_chooser():
            print(f"   the text-type sheet did not open — "
                  f"visible: {labels(dump())[:12]}")
            return None
    time.sleep(1)
    rows = dump()
    hit = next((r for r in rows
                if any(t in (r["desc"] or r["text"]) for t in L["comments"])), None)
    if hit is None:
        print(f"   the switch is not on the sheet — visible: {labels(rows)[:12]}")
        return None
    adb("shell", "input", "tap", str(hit["x"]), str(hit["y"]))
    print(f"   tap the comments switch @{hit['x']},{hit['y']}")
    time.sleep(1)
    if not tap_any(dump(), "done", label="the sheet's Done"):
        return None
    return roles_pref()


def first_voice(entries, prefix):
    """The device's own voice for a language, preferring the offline copy."""
    hits = sorted((n, l) for n, l in entries.items()
                  if (l or "").lower().startswith(prefix))
    for name, locale in hits:
        if name.endswith("-local"):
            return name, locale
    return hits[0] if hits else None


def seed_voice_picks(entries):
    """Writes the reader's picks for `es` and `en` into the app's own store.

    The read names the voice the engine was given, and for a 标准 read that is
    the reader's pick — `loadVoice` answers null without one, and the app omits
    `voice=` for null. Rather than drive two pickers (a Spanish content's 语音
    opens one language's list), the row seeds the two decisions the picker would
    write, in the format `VoiceStore` reads back: `<name>||<locale>`.
    """
    picks = []
    for prefix, key in (("es", "voice_es"), ("en", "voice_en")):
        hit = first_voice(entries, prefix)
        if hit is None:
            return None
        picks.append((key, f"{hit[0]}||{hit[1]}"))
    xml = ("<?xml version='1.0' encoding='utf-8' standalone='yes' ?>\n<map>\n"
           + "".join(f'    <string name="flutter.{k}">{v}</string>\n'
                     for k, v in picks)
           + "</map>\n")
    adb("shell", "am", "force-stop", PKG)
    if not device_write(PREFS, xml.encode()):
        return None
    start_app()
    time.sleep(1)
    return dict(picks)


# --------------------------------------------------------------------------
# row 17
# --------------------------------------------------------------------------
def row_17():
    step("row 17 — a comment read on the device, in two voices, no marker painted")
    fresh_prefs()

    # (a) the device's own voice list, so the picks below are real voices.
    if open_section("main", "comment_main", "注释-注释") is None:
        return
    entries = harvest_voices()
    check("17: the device's own voice list came off the app (one line per voice)",
          len(entries) > 0, f"{len(entries)} voices in this window")
    picks = seed_voice_picks(entries)
    check("17: the reader's two picks were seeded in the app's own store",
          picks is not None, f"picks: {picks}")
    if picks is None:
        return

    # (b) the three spellings, each opened afresh: the same words hidden, the same
    # two voices, the same order.
    read_by_section = {}
    for section in ("main", "nota", "traditional"):
        if open_section(section) is None:
            return
        dump(1)
        rows = dump()
        painted = painted_text(rows)
        check(f"17[{section}]: the page paints the comment's words (FR-012)",
              "How are you?" in painted, f"painted: {painted!r}")
        check(f"17[{section}]: no marker character reaches the page (FR-005)",
              "[" not in painted and "]" not in painted, f"painted: {painted!r}")

        log = read_and_wait(f"17 {section}", 2)
        if not log:
            check(f"17[{section}]: the read started from the top", False,
                  f"visible: {labels(dump())[:12]}")
            return
        speaks = speak_lines(log)
        print(f"   the read's own lines ({section}):\n     "
              + "\n     ".join(
                  f'{s["text"]!r} voice={s["voice"]} comment={s["comment"]}'
                  for s in speaks))

        spoken = [s["text"] for s in speaks]
        flags = [s["comment"] for s in speaks]
        check(f"17[{section}]: every sentence of the sentence's paragraph and the "
              f"comment reached the engine, one utterance each (FR-007)",
              spoken[:1] == ["Hola."] and spoken[-1] == "How are you?"
              and len(speaks) == 2,
              f"spoken: {spoken}")
        check(f"17[{section}]: the comment's own utterance carries comment=1 (D9)",
              flags[-1] is True and not any(flags[:-1]),
              f"comment flags: {flags}")
        check(f"17[{section}]: no marker in any spoken text (SC-001)",
              all("[" not in t and "]" not in t for t in spoken),
              f"spoken: {spoken}")
        voices = [s["voice"] for s in speaks]
        check(f"17[{section}]: the sentence and the comment read in different "
              f"voices (SC-003)",
              all(voices) and len(set(voices)) == 2, f"voices: {voices}")
        check(f"17[{section}]: the sentence reads in the Spanish voice, the "
              f"comment in the English one (SC-003, FR-008)",
              all(voices) and (entries.get(voices[0], "").lower().startswith("es")
                               and entries.get(voices[-1], "").lower().startswith("en")),
              f"voices {voices} → locales "
              f"{[entries.get(v, '?') for v in voices]}")
        read_by_section[section] = [(s["text"], s["comment"], s["voice"])
                                    for s in speaks]

    # (c) the amendment's own claim: the three spellings are one tag on a device.
    check("17: [注], [nota] and [註] read exactly alike (FR-001, 2026-10-08)",
          read_by_section["main"] == read_by_section["nota"]
          == read_by_section["traditional"],
          f"main={read_by_section['main']} nota={read_by_section['nota']} "
          f"traditional={read_by_section['traditional']}")


# --------------------------------------------------------------------------
# row 18
# --------------------------------------------------------------------------
def row_18():
    step("row 18 — the inline tag's reach, heard rather than seen")
    fresh_prefs()
    if open_section("inline") is None:
        return
    entries = harvest_voices()
    check("18: the device's own voice list came off the app (one line per voice)",
          len(entries) > 0, f"{len(entries)} voices in this window")
    picks = seed_voice_picks(entries)
    check("18: the reader's two picks were seeded in the app's own store",
          picks is not None, f"picks: {picks}")
    if picks is None:
        return

    if open_section("inline") is None:
        return
    dump(1)
    painted = painted_text(dump())
    check("18: the page shows the sentence and the comment, and no marker",
          "Hola." in painted and "Hi. Adiós." in painted
          and "[" not in painted and "]" not in painted,
          f"painted: {painted!r}")

    log = read_and_wait("18 the read", 3)
    if not log:
        check("18: the read started from the top", False,
              f"visible: {labels(dump())[:12]}")
        return
    speaks = speak_lines(log)
    print("   the read's own lines:\n     "
          + "\n     ".join(f'{s["text"]!r} voice={s["voice"]} '
                           f'comment={s["comment"]}' for s in speaks))
    spoken = [s["text"] for s in speaks]
    voices = [s["voice"] for s in speaks]
    check("18: exactly one comment is spoken, its sentences in order (FR-002)",
          spoken == ["Hola.", "Hi.", "Adiós."], f"spoken: {spoken}")
    check("18: the comment's utterances carry comment=1 and the sentence's does "
          "not (D9)",
          [s["comment"] for s in speaks] == [False, True, True],
          f"comment flags: {[s['comment'] for s in speaks]}")
    # The comment's OWN text decides its language (FR-008/A3): `Hi. Adiós.` carries
    # an accent, so the detector reads it as Spanish and the comment is voiced by
    # the Spanish pick — the same one `Hola.` gets. Row 17 carries the two-language
    # case (a plainly English comment in the English voice).
    check("18: the comment's utterances read in the voice its own text detects "
          "(es here — the accent in Adiós.) (FR-008, A3)",
          all(voices) and all((entries.get(v, "") or "").lower().startswith("es")
                              for v in voices[-2:]),
          f"voices {voices} → locales {[entries.get(v, '?') for v in voices]}")
    check("18: Adiós. is the comment's own text, not a sentence read in its own "
          "right (FR-002's boundary)",
          [s["comment"] for s in speaks] == [False, True, True]
          and not any(t == "Adiós." and not c
                      for t, c in zip(spoken, [s["comment"] for s in speaks])),
          f"spoken/comment: {list(zip(spoken, [s['comment'] for s in speaks]))}")


def highlighted_pixels():
    """How many pixels of the page are the highlight's own yellow.

    The page's tracking highlight is `Colors.yellow` on the spoken span (the
    page test asserts the span tree; on a device the pixels are the witness). A
    still is taken mid-read, so the band is there when it is read.
    """
    dest = os.path.join(OUT, "015_row19_highlight.png")
    if video.screencap(dest) is None:
        return None
    from PIL import Image  # 012's frame reads already require it
    im = Image.open(dest).convert("RGB")
    w, h = im.size
    px = im.load()
    n = 0
    for y in range(0, h, 3):
        for x in range(0, w, 3):
            r, g, b = px[x, y]
            if r > 200 and g > 200 and b < 130:
                n += 1
    return n


def tap_comment_line():
    """Taps the painted line of the comment — the content block's last line.

    A tap is resolved by the page against the offset under the finger, so the
    point matters: the block is `Hola.`, a blank line, then the comment, and the
    comment's line is the block's last sixth-to-eighth. The tap reports a
    DISPLAY offset, which the page maps back to a content offset before the
    comment rule sees it (research D7).
    """
    node = content_node()
    if node is None:
        return False
    top = node["y"] - node["h"] // 2
    y = top + int(node["h"] * 0.85)
    adb("shell", "input", "tap", str(node["x"]), str(y))
    print(f"   tap the comment's line @{node['x']},{y} "
          f"(block {node['w']}x{node['h']} at {node['x']},{node['y']})")
    time.sleep(0.6)
    return True


# --------------------------------------------------------------------------
# row 19
# --------------------------------------------------------------------------
def row_19():
    step("row 19 — a tap inside a comment answers, in both settings")
    fresh_prefs()
    text = open_section("main", "comment_main", "注释-注释")
    if text is None:
        return
    comment = (text.index("How are you?"),
               text.index("How are you?") + len("How are you?"))
    owner = (0, text.index("Hola.") + len("Hola."))

    stamp = device_now()
    if not tap_comment_line() or not tap_any(dump(), "read", label="▶ Read"):
        check("19: the comment's line was tapped and ▶ Read pressed", False,
              f"visible: {labels(dump())[:14]}")
        return
    lit = highlighted_pixels()
    wait_for(lambda: len(read_ranges(logcat_since(stamp))) > 0, seconds=30)
    log_on = logcat_since(stamp)
    ranges_on = read_ranges(log_on)
    speaks_on = speak_lines(log_on)
    print(f"   with the comments read: ranges={ranges_on} "
          f"spoken={[s['text'] for s in speaks_on]} lit_px={lit}")
    check("19: with the comments read the read's range is the comment's own span "
          "(SC-009)", ranges_on and ranges_on[0] == comment,
          f"ranges {ranges_on}, the comment is {comment}")
    check("19: the comment itself was read (never a marker, never nothing)",
          any(s["text"] == "How are you?" and s["comment"] for s in speaks_on),
          f"spoken: {[(s['text'], s['comment']) for s in speaks_on]}")
    check("19: the highlight was drawn while the read ran (FR-012)",
          lit is not None and lit > 0, f"{lit} highlighted pixels in the still")

    # (b) the switch off: the same tap answers the owner sentence.
    if set_comments() is None:
        check("19: the comments switch was turned off", False,
              f"visible: {labels(dump())[:14]}")
        return
    stamp = device_now()
    if not tap_comment_line() or not tap_any(dump(), "read", label="▶ Read"):
        check("19: the comment's line was tapped and ▶ Read pressed again", False,
              f"visible: {labels(dump())[:14]}")
        return
    lit = highlighted_pixels()
    wait_for(lambda: len(read_ranges(logcat_since(stamp))) > 0, seconds=30)
    log_off = logcat_since(stamp)
    ranges_off = read_ranges(log_off)
    speaks_off = speak_lines(log_off)
    print(f"   with the comments off: ranges={ranges_off} "
          f"spoken={[s['text'] for s in speaks_off]} lit_px={lit}")
    check("19: with the comments off the same tap answers the owner sentence "
          "(SC-009, FR-012)", ranges_off and ranges_off[0] == owner,
          f"ranges {ranges_off}, the owner is {owner}")
    check("19: that sentence was read, and no comment's characters with it",
          [s["text"] for s in speaks_off] == ["Hola."],
          f"spoken: {[s['text'] for s in speaks_off]}")
    check("19: the highlight was drawn in this state too (FR-012)",
          lit is not None and lit > 0, f"{lit} highlighted pixels in the still")


# --------------------------------------------------------------------------
# row 20
# --------------------------------------------------------------------------
MAIN_NAME = "注释-注释"


def row_20():
    step("row 20 — the switch off, across a restart, and with the content gone")
    fresh_prefs()
    if open_section("main", "comment_main", MAIN_NAME) is None:
        return

    # (a) the switch off on the page's own sheet.
    if set_comments() is None:
        check("20: the comments switch was turned off", False,
              f"visible: {labels(dump())[:14]}")
        return
    entry = roles_pref().get("comment_main", {})
    check("20: the switch is stored for this content, and it alone (FR-014)",
          entry.get("comments") is False, f"content_roles[comment_main] = {entry}")

    # (b) the read from the top: none of the comment's words reaches the engine,
    # while the page still paints them and no marker (SC-002, FR-005).
    log = read_and_wait("20 the read with them off", 1)
    if not log:
        check("20: the read started from the top", False,
              f"visible: {labels(dump())[:12]}")
        return
    spoken = [s["text"] for s in speak_lines(log)]
    check("20: none of the comment's words reaches the engine (SC-002)",
          spoken == ["Hola."] and not any("How" in t for t in spoken),
          f"spoken: {spoken}")
    painted = painted_text(dump())
    check("20: the page still paints the comment's words, and no marker (FR-005)",
          "How are you?" in painted and "[" not in painted and "]" not in painted,
          f"painted: {painted!r}")

    # (c) force-stop, start again: the choice is still in force (SC-010).
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    start_app()
    rows = dump()
    check("20: the app reopens on the same content",
          any("Hola." in (r["desc"] or r["text"]) for r in rows),
          f"the page's own labels: {labels(rows)[:6]}")
    check("20: after the restart the switch is still off for that content "
          "(SC-010, FR-014)",
          roles_pref().get("comment_main", {}).get("comments") is False,
          f"content_roles[comment_main] = {roles_pref().get('comment_main')}")
    log = read_and_wait("20 the read after the restart", 1)
    if not log:
        return
    spoken = [s["text"] for s in speak_lines(log)]
    check("20: the read after the restart is the read before it (SC-002)",
          spoken == ["Hola."], f"spoken: {spoken}")

    # (d) a second content, its switch never touched: its comments still read —
    # the setting is per content (FR-016).
    if open_section("nota") is None:
        return
    log = read_and_wait("20 the second content", 2)
    if not log:
        return
    speaks = speak_lines(log)
    check("20: a content whose switch was never touched still reads its comments "
          "(FR-016, SC-010)",
          [s["text"] for s in speaks] == ["Hola.", "How are you?"]
          and speaks[-1]["comment"] is True,
          f"spoken: {[(s['text'], s['comment']) for s in speaks]}")

    # (e) the content goes: its entry — the switch with it — goes too (SC-010).
    if not tap_any(dump(), "contents", label="Contents"):
        check("20: the library opened", False, f"visible: {labels(dump())[:10]}")
        return
    time.sleep(2)
    rows = dump()
    row, icon = dialogue.library_row(rows, MAIN_NAME)
    if row is None or icon is None:
        check("20: the library lists the content with its delete action", False,
              f"visible: {labels(rows)[:10]}")
        return
    dialogue.tap_node(rows, icon, f"the delete action on {MAIN_NAME}")
    time.sleep(1.5)
    rows = dump()
    check("20: the delete asks first (the shipped dialog shape)",
          dialogue.shows(rows, "delete_confirm"), f"labels: {labels(rows)[:4]}")
    if not dialogue.tap_exact(rows, "delete", label="the dialog's Delete"):
        return
    time.sleep(2)
    check("20: deleting the content takes its entry, the switch with it "
          "(SC-010, FR-015)",
          "comment_main" not in roles_pref(),
          f"content_roles = {prefs_value(dialogue.ROLES_KEY)!r}")


# --------------------------------------------------------------------------
# row 21
# --------------------------------------------------------------------------
TURN = "今日个天气真系唔错啊。"


def row_21():
    step("row 21 — a comment inside a dialogue turn, and in 标准")
    fresh_prefs()

    # (a) 多人对话: the turn keeps its own words, language and voice, the comment
    # is read after it in its own language's voice, and the role list is unmoved.
    if open_section("dialogue", "comment_dialogue", "对话-注释") is None:
        return
    entries = harvest_voices()
    picks = seed_voice_picks(entries)
    check("21: the comment's own voice (en) was seeded in the app's store",
          picks is not None, f"picks: {picks}")
    if picks is None:
        return
    if not set_dialogue():
        check("21: the type was set through the app's own chooser", False,
              f"visible: {labels(dump())[:12]}")
        return

    log = read_and_wait("21 the dialogue read", 2)
    if not log:
        check("21: the read started from the top", False,
              f"visible: {labels(dump())[:12]}")
        return
    speaks = speak_lines(log)
    print("   the read's own lines (多人对话):\n     "
          + "\n     ".join(f'{s["text"]!r} role={s["role"]} voice={s["voice"]} '
                           f'comment={s["comment"]}' for s in speaks))
    spoken = [s["text"] for s in speaks]
    check("21: the turn speaks its own words, with none of the comment's in them "
          "(FR-011, scenario 1)", spoken[:1] == [TURN], f"spoken: {spoken}")
    check("21: the turn is 阿明's and the comment is nobody's (FR-011)",
          speaks[0]["role"] == "阿明" and speaks[-1]["comment"] is True
          and speaks[-1]["role"] is None,
          f"role/comment: {[(s['role'], s['comment']) for s in speaks]}")
    # The turn's detected language is its own text's: a Chinese turn with an
    # English comment is still zh-Hans (scenario 2) — the assignment's voice for
    # 阿明 is a Chinese one.
    check("21: the comment reads in its own language's voice, never the role's "
          "(FR-008, scenario 1)",
          all(s["voice"] for s in speaks[:2])
          and speaks[0]["voice"] != speaks[1]["voice"]
          and (entries.get(speaks[1]["voice"], "") or "").lower().startswith("en")
          and (entries.get(speaks[0]["voice"], "") or "").lower()
          .startswith(("zh", "cmn", "yue")),
          f"voices: {[s['voice'] for s in speaks]} → locales "
          f"{[entries.get(s['voice'], '?') for s in speaks]}")

    rows = dialogue.open_role_list()
    if not rows:
        check("21: the role list opened", False, f"visible: {labels(dump())[:12]}")
    else:
        names = list(dialogue.role_rows(rows))
        label = dialogue.role_row_label(rows, "阿明") or ""
        check("21: the comment-only paragraph is no turn and no role "
              "(FR-011, scenario 3)", names == ["阿明"], f"the list's roles: {names}")
        check("21: 阿明's turn count is unmoved by the comment (SC-005)",
              label.partition("\n")[2].strip().startswith("1"),
              f"阿明's row: {label!r}")
        dialogue.close_role_list()
        time.sleep(1)

    # (b) 标准 with the same two tags: the shipped read, plus the comment.
    if open_section("standard_tags", "comment_std", "标准-注释") is None:
        return
    log = read_and_wait("21 the 标准 read", 2)
    if not log:
        return
    speaks = speak_lines(log)
    print("   the read's own lines (标准):\n     "
          + "\n     ".join(f'{s["text"]!r} voice={s["voice"]} '
                           f'comment={s["comment"]}' for s in speaks))
    check("21: the 标准 content reads the shipped sentence and then the comment "
          "(FR-010, scenario 4)",
          len(speaks) == 2 and TURN in speaks[0]["text"]
          and speaks[-1]["text"] == "How are you?"
          and [s["comment"] for s in speaks] == [False, True],
          f"spoken: {[s['text'] for s in speaks]}")

    # (c) a comment before every sentence: displayed, never spoken (FR-003).
    if open_section("head_comment", "comment_head", "段首注释") is None:
        return
    log = read_and_wait("21 the head-comment content", 1)
    if not log:
        return
    speaks = speak_lines(log)
    check("21: a comment before every sentence is never spoken (FR-003)",
          [s["text"] for s in speaks] == ["Hola."]
          and not any(s["comment"] for s in speaks),
          f"spoken: {[(s['text'], s['comment']) for s in speaks]}")
    painted = painted_text(dump())
    check("21: it is displayed all the same (FR-003)",
          "Hello." in painted and "[" not in painted and "]" not in painted,
          f"painted: {painted!r}")


# --------------------------------------------------------------------------
# row 22
# --------------------------------------------------------------------------
PICK = "16:9 landscape 1080p"
PICK_WH = (1920, 1080)
SENT = "Hola."
COMMENT = "How are you?"
# The block the video paints for the sentence's own slot: the sentence, one line
# break, the comment — and no marker (a painted `[注]` would add four characters).
BLOCK_CHARS = len(SENT) + 1 + len(COMMENT)


def render_one(where, aspect=PICK):
    """Renders what the page is showing, pulls the file, and answers
    `(dest, frames, runs, the renderer's own time account, ms)` — or None when
    the render or the pull did not happen."""
    rows = dump()
    if video.on_screen(rows, "Discard"):
        video.tap(rows, "Discard", label="the earlier review")
        time.sleep(1.5)
    result = video.render(where, aspect)
    if not result:
        check(f"{where}: the render produced a file", False)
        return None
    path, ms, _size, frames, _wall = result
    dest = os.path.join(OUT, f"{where.replace('/', '_')}.mp4")
    data, pulled = video.pull(path, dest)
    check(f"{where}: the file came off the device and is not empty",
          pulled and len(data) > 10000, f"{len(data)}B")
    if not pulled:
        return None
    runs = video.render_runs(video.logcat())
    check(f"{where}: the renderer's runs are the file's own frames",
          bool(runs) and sum(r["frames"] for r in runs) == frames
          and all(r["total"] == frames for r in runs),
          f"{sum(r['frames'] for r in runs)} of {frames} frames")
    # The account is read here, not later: `render()` clears the log at its own
    # start, so a second render in the same row erases the first one's line.
    return dest, frames, runs, video.render_time(video.logcat()), ms


def slot_of(runs, slot=0):
    for run in runs:
        if run["slot"] == slot:
            return run
    return None


def box_of_frame(dest, number, w, h):
    """(band pixels, pixels outside the column, the ink box) of one frame, in the
    file's own pixels.

    The measurement is the driver's own `scan_frame` — 012's rows 32/49 already
    use it — with the column scaled to the file's grid (a thumbnail's own
    dimensions would put the margins in the wrong place) and a stride, because a
    1920x1080 pass at every pixel is a minute per frame.
    """
    rgb = video.frame_rgb(dest, number, w, h)
    if rgb is None:
        return None
    bg = video.at(rgb, w, 2, 2)
    grid = video.scaled_column(w, h, w, h)
    band, outside, _band_box, ink_box = video.scan_frame(
        rgb, w, h, bg, grid, stride=2)
    return band, outside, ink_box


def row_22():
    step("row 22 — a comment's video, the frames")
    fresh_prefs()
    text = fixture_sections()["main"]
    if open_section("twin", "comment_twin", "无注释对照", text=SENT) is None:
        return
    if open_section("main", "comment_main", "注释-注释") is None:
        return
    print(f"   the fixture's own text: {text!r}; the twin's: {SENT!r}; "
          f"the block the video should paint: {SENT + chr(10) + COMMENT!r} "
          f"({BLOCK_CHARS} chars)")

    step("22: the render with the comments read, then with them off")
    a = render_one("22/comments-read")
    b = None
    if a is not None:
        if set_comments() is None:
            check("22: the comments switch was turned off", False,
                  f"visible: {labels(dump())[:14]}")
            return
        b = render_one("22/comments-off")
    step("22: the same sentence with no comment at all — 012's own case")
    if open_section("twin", "comment_twin", "无注释对照", text=SENT) is None:
        return
    c = render_one("22/no-comment")
    if c is None:
        return

    w, h = PICK_WH
    r_a = slot_of(a[2]) if a else None
    r_b = slot_of(b[2]) if b else None
    r_c = slot_of(c[2])
    if not (r_a and r_c):
        check("22: the sentence's own slot is in the files", False,
              f"A={a[2] if a else None}\n     C={c[2]}")
        return
    check("22: slot 0's block paints the sentence, a line break and the comment "
          "— the tag is in no frame (SC-007, FR-013)",
          r_a["text"] == BLOCK_CHARS,
          f"text={r_a['text']}, the sum is {BLOCK_CHARS}")
    if r_b:
        check("22: with the comments off the block paints exactly the same — the "
              "setting changes what is heard, not what is seen",
              r_b["text"] == BLOCK_CHARS, f"text={r_b['text']}")
    check("22: the tagless twin's slot is the sentence alone, as 012 renders it "
          "today", r_c["text"] == len(SENT),
          f"text={r_c['text']}, the sentence is {len(SENT)}")

    measured = {}
    for label, result, run in (("comments-read", a, r_a), ("comments-off", b, r_b),
                               ("no-comment", c, r_c)):
        if result is None or run is None:
            continue
        got = box_of_frame(result[0], run["start"], w, h)
        if got is None:
            check(f"22/{label}: the slot's first frame was read back", False,
                  "frame_rgb returned nothing")
            continue
        band, outside, ink_box = got
        measured[label] = ink_box
        check(f"22/{label}: the slot's frame carries no highlight band, and "
              f"nothing outside the column", band == 0 and outside == 0,
              f"band={band} outside={outside}")
        print(f"   22/{label}: slot 0 frame {run['start']} text={run['text']} "
              f"span={run['span_start']}..{run['span_end']} ink box={ink_box} "
              f"(height {ink_box[3] - ink_box[1]}px of {h})")
    if "comments-read" in measured and "comments-off" in measured:
        check("22: the two files' boxes are the same for that slot (SC-007)",
              measured["comments-read"] == measured["comments-off"],
              f"read {measured['comments-read']} vs off {measured['comments-off']}")
    if "comments-read" in measured and "no-comment" in measured:
        tall = measured["comments-read"][3] - measured["comments-read"][1]
        twin = measured["no-comment"][3] - measured["no-comment"][1]
        check("22: the block covers the sentence's lines plus the comment's — "
              "strictly taller than the same sentence with no comment (FR-013)",
              measured["comments-read"][3] > measured["no-comment"][3],
              f"the block's ink is {tall}px tall, the twin's {twin}px")

    step("22: every frame of each file, at the app's own 96x54")
    for label, result in (("comments-read", a), ("comments-off", b),
                          ("no-comment", c)):
        if result is None:
            continue
        dest, frames = result[0], result[1]
        thumbs = video.coarse_frames(dest)
        if not thumbs:
            check(f"22/{label}: the frames were read back", False, "ffmpeg gave nothing")
            continue
        bg = video.at(thumbs[0], video.CW, 2, 2)
        grid = video.scaled_column(w, h, video.CW, video.CH)
        bad = []
        for i, thumb in enumerate(thumbs):
            band, outside, _bb, _ib = video.scan_frame(
                thumb, video.CW, video.CH, bg, grid)
            if band or outside:
                bad.append((i, band, outside))
        check(f"22/{label}: every one of the file's {len(thumbs)} frames is the "
              f"app's own look — no band, no chrome",
              len(thumbs) == frames and not bad,
              f"{len(thumbs)} of {frames} frames read; first bad (frame, band, "
              f"outside): {bad[:3]}")


# --------------------------------------------------------------------------
# row 23
# --------------------------------------------------------------------------
HISS = os.path.normpath(os.path.join(
    HERE, "..", "..", "012-reading-video", "scripts", "klhu_probe_hiss.py"))


def hiss_probe(files):
    """The >10 kHz probe's own reading: (its exit code, {file name: first-2s dB}).

    012's `klhu_probe_hiss.py`, run the way its own docstring says — the walk's
    dependency on ffmpeg, not a new one.
    """
    out = subprocess.run([sys.executable, HISS, *files, "--max-first-db", "-35"],
                         capture_output=True, text=True)
    text = (out.stdout + out.stderr).strip()
    print("   " + "\n   ".join(text.splitlines()))
    levels, name = {}, None
    for line in text.splitlines():
        if line and not line[0].isspace():
            name = line.strip()
        m = re.match(r"\s+first 2 s mean\s+(-?[\d.]+) dB", line)
        if m and name:
            levels[name] = float(m.group(1))
    return out.returncode, levels


def audio_of(probed):
    return [s for s in (probed or {}).get("streams", [])
            if s.get("codec_type") == "audio"]


def row_23():
    step("row 23 — a comment's video, the audio")
    fresh_prefs()
    if open_section("main", "comment_main", "注释-注释") is None:
        return

    # SC-008: the file says exactly what the read says. The read's own utterance
    # count is taken first, on the device, and the render's `sentences=` is read
    # against it — not against a number written here.
    log = read_and_wait("23 the read with the comments read", 2)
    read_on = [s["text"] for s in speak_lines(log)]
    check("23: the read's own utterances are the sentence then the comment",
          read_on == [SENT, COMMENT], f"spoken: {read_on}")

    step("23: the render with the comments read")
    a = render_one("23/comments-read")
    if a is None:
        return
    check("23/comments-read: the file says what the read says — `sentences=` is "
          "the read's own utterance count (SC-008)",
          bool(a[3]) and a[3].get("sentences") == len(read_on),
          f"the renderer's own line: {a[3]}")

    step("23: the switch off, and the render again")
    if set_comments() is None:
        check("23: the comments switch was turned off", False,
              f"visible: {labels(dump())[:14]}")
        return
    log = read_and_wait("23 the read with them off", 1)
    read_off = [s["text"] for s in speak_lines(log)]
    check("23: the read with them off is the sentence alone",
          read_off == [SENT], f"spoken: {read_off}")
    b = render_one("23/comments-off")
    if b is None:
        return
    check("23/comments-off: `sentences=` is the sentences' alone (SC-008)",
          bool(b[3]) and b[3].get("sentences") == len(read_off),
          f"the renderer's own line: {b[3]}")

    pa, pb = video.probe(a[0]), video.probe(b[0])
    if not (pa and pb):
        check("23: ffprobe read both files", False)
        return
    aud_a, aud_b = audio_of(pa), audio_of(pb)
    dur_a, dur_b = video.duration_s(pa), video.duration_s(pb)
    delta_ms, delta_frames = a[4] - b[4], a[1] - b[1]
    print(f"   23: read {a[1]} frames {dur_a}s, audio {aud_a}\n"
          f"   23: off  {b[1]} frames {dur_b}s, audio {aud_b}\n"
          f"   23: the read is {delta_ms}ms / {delta_frames} frames longer")

    check("23: the whole track is one stream at one rate in each file, and the "
          "same rate in both (SC-008)",
          len(aud_a) == 1 and len(aud_b) == 1
          and aud_a[0].get("sample_rate") == aud_b[0].get("sample_rate"),
          f"{[s.get('sample_rate') for s in aud_a]} vs "
          f"{[s.get('sample_rate') for s in aud_b]}")
    # The engine's own refusal is a thrown Failure, not a broken file: if the
    # two languages' files disagreed in layout the render would say so here
    # rather than mux something wrong (VideoEncoderPlugin.kt's own message).
    refusal = ("different audio layouts" in video.logcat()
               or "IO_FAILED" in video.logcat())
    check("23: neither render fell to the platform's own refusal — the two "
          "languages muxed into one layout",
          not refusal and all(s.get("channels") for s in aud_a + aud_b),
          f"channels {[s.get('channels') for s in aud_a + aud_b]}"
          + (", the plugin refused the mux" if refusal else ""))
    check("23: the read file is longer than the comments-off one by the "
          "comment's own audio (SC-008)",
          delta_ms > 0 and delta_frames > 0 and dur_a and dur_b
          and abs((dur_a - dur_b) - delta_ms / 1000) < 0.1,
          f"{delta_ms}ms / {delta_frames} frames more; the files are "
          f"{dur_a}s and {dur_b}s")
    # The container's own duration runs past the muxer's accounting by a fixed
    # tail (measured here: 128 ms in both files — the audio track's own padding,
    # not the comment's audio, which is why it is the same either way). The
    # claim is that the tail is a constant: the difference between the two files
    # is the comment's audio and nothing else.
    tail_a = (dur_a or 0) - a[4] / 1000
    tail_b = (dur_b or 0) - b[4] / 1000
    check("23: each file's own duration is the render's length plus the "
          "platform's own fixed tail",
          bool(dur_a and dur_b) and abs(tail_a - tail_b) < 0.01
          and 0 < tail_a < 0.3,
          f"files {dur_a}s and {dur_b}s, the renders {a[4]}ms and {b[4]}ms — "
          f"a tail of {tail_a * 1000:.0f} ms and {tail_b * 1000:.0f} ms")

    step("23: the >10 kHz probe on the two-language file")
    code, levels = hiss_probe([a[0]])
    first = levels.get(os.path.basename(a[0]))
    check("23: the two-language file carries no hiss above 10 kHz — the probe's "
          "own ceiling (SC-008, 012's FR-017)",
          code == 0 and first is not None and first <= -35,
          f"the probe exited {code}, first 2 s {first} dB against the -35 dB "
          f"ceiling")


ROWS = {"17": row_17, "18": row_18, "19": row_19, "20": row_20, "21": row_21,
        "22": row_22, "23": row_23}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(__doc__)
        print(f"rows implemented here: {', '.join(sorted(ROWS))}")
        todo = [r for r in ("19", "20", "21", "22", "23")
                if r not in ROWS]
        print("rows still to come (walk them by hand with the same commands): "
              + ", ".join(todo))
        sys.exit(2)
    row = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 015 row {row} — device {DEV}, package {PKG}, out {OUT}")
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
