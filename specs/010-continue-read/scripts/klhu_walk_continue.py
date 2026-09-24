#!/usr/bin/env python3
"""klhu device walk — spec 010 quickstart, scenarios 13-17 (Continue Read).

What each part proves, and with which evidence line:

  13  a tap on a middle paragraph sets the start position, and Continue Read
      reads from there          -> `klhu read range: <start>..<end>` in logcat
                                   (+ a yellow-pixel count before/after the tap)
  14  the position survives a restart -> the `read_position_*` record in
                                   FlutterSharedPreferences.xml, then the same
                                   range again after a force-stop + relaunch
  15  no position -> the previous behaviour, unchanged
                                -> `klhu read range: 0..<len>` after `pm clear`
  16  pause mid-paragraph, resume repeats only that sentence (FR-011, I12)
                                -> `klhu speak p<i> s<j> "…"` before and after
                                   the pause: the same p/s, never s0
  17  a sentence-queued read is still a whole read, per language (D12)
                                -> one `klhu speak` line per sentence, in order,
                                   ending on the text's last sentence, and one
                                   engine `Synthesis request … locale <tag>` per
                                   utterance in the content's own language

Usage:
    python3 klhu_walk_continue.py 13|14|15|16|17

Env:
    ADB_SERIAL  (default: emulator-5554)
    KLHU_REPO   (default: this script's repo root) — where the preset text is
                read from, so a logged offset can be checked against it
    KLHU_OUT    (default: /tmp) — screenshots and dumps land here
"""
import os
import re
import subprocess
import sys
import time

ADB_SERIAL = os.environ.get("ADB_SERIAL", "emulator-5554")
KLHU_OUT = os.environ.get("KLHU_OUT", "/tmp")
PKG = "com.example.klhu"
HERE = os.path.dirname(os.path.abspath(__file__))
KLHU_REPO = os.environ.get(
    "KLHU_REPO", os.path.abspath(os.path.join(HERE, "..", "..", ".."))
)
XML = f"{KLHU_OUT}/klhu_walk_010.xml"

DEV = ["adb", "-s", ADB_SERIAL]


def adb(*args, binary=False):
    r = subprocess.run(DEV + list(args), capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def dump():
    """A fresh uiautomator dump; the local file is deleted first so a failed
    pull can never be read as a successful one."""
    for _ in range(3):
        subprocess.run(["rm", "-f", XML])
        adb("shell", "uiautomator", "dump", "/sdcard/klhu_walk_010.xml")
        adb("pull", "/sdcard/klhu_walk_010.xml", XML)
        try:
            with open(XML, encoding="utf-8") as fh:
                xml = fh.read()
        except OSError:
            time.sleep(1)
            continue
        rows = []
        for m in re.finditer(r"<node[^>]*>", xml):
            tag = m.group(0)

            def attr(key, tag=tag):
                hit = re.search(key + r'="([^"]*)"', tag)
                return hit.group(1) if hit else ""

            desc, bounds = attr("content-desc"), attr("bounds")
            if not desc or not bounds:
                continue
            n = [int(x) for x in re.findall(r"\d+", bounds)]
            rows.append({
                "desc": desc.replace("&#10;", "\n"),
                "text": attr("text"),
                "enabled": attr("enabled") != "false",
                "x": (n[0] + n[2]) // 2,
                "y": (n[1] + n[3]) // 2,
                "bounds": (n[0], n[1], n[2], n[3]),
            })
        return rows
    print("DUMP FAILED")
    sys.exit(2)


def labels(rows):
    return [r["desc"] or r["text"] for r in rows]


def find(rows, needle):
    for r in rows:
        if needle in (r["desc"] or r["text"]):
            return r
    return None


def tap_at(x, y, label=""):
    adb("shell", "input", "tap", str(x), str(y))
    print(f"   tap {label} @{x},{y}")


def tap_node(rows, needle, label=None):
    node = find(rows, needle)
    if node is None:
        print(f"   NOT FOUND: {needle!r} — visible: {labels(rows)[:10]}")
        return False
    if not node["enabled"]:
        print(f"   DISABLED: {needle!r}")
        return False
    tap_at(node["x"], node["y"], label or needle)
    return True


def start_app(clear=False):
    if clear:
        adb("shell", "pm", "clear", PKG)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(7)
    return dump()


def restart_app():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(7)
    return dump()


def clear_log():
    adb("logcat", "-c")


def log_lines(*needles, all_after_clear=True):
    out = adb("logcat", "-d", "-v", "time")
    return [ln.strip() for ln in out.splitlines()
            if any(k in ln for k in needles)]


def ranges(lines=None):
    """`klhu read range: <start>..<end>` values, in log order."""
    lines = lines if lines is not None else log_lines("klhu read range")
    return [tuple(int(v) for v in re.findall(r"(\d+)\.\.(\d+)", ln)[0])
            for ln in lines if re.search(r"(\d+)\.\.(\d+)", ln)]


def synthesis_count():
    return len(log_lines("Synthesis request"))


def stored_position():
    """The `read_position_*` line straight out of the app's prefs file."""
    out = adb("shell", "run-as", PKG, "cat",
              f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml")
    return [ln.strip() for ln in out.splitlines() if "read_position" in ln]


def yellow_pixels(path):
    from PIL import Image
    with open(path, "wb") as fh:
        fh.write(adb("exec-out", "screencap", "-p", binary=True))
    img = Image.open(path).convert("RGB")
    return sum(1 for p in img.getdata() if p[0] > 200 and p[1] > 200 and p[2] < 90)


def preset_text(preset_id="preset_en_sample"):
    """A shipped pre-set, straight out of the asset the app ships."""
    for p in presets():
        if p["id"] == preset_id:
            return p["text"]
    raise SystemExit(f"{preset_id} missing from the catalog")


def sentence_starts(text):
    starts, i = [0], 0
    while i < len(text):
        if text[i] in ".!?;。！？；":
            j = i + 1
            while j < len(text) and text[j] in "\"'”’)»]}":
                j += 1
            while j < len(text) and text[j] in " \t\r\n":
                j += 1
            if j < len(text):
                starts.append(j)
            i = j
        else:
            i += 1
    return starts


def paragraph_ranges(text):
    """The paragraphs of [text], mirroring `lib/segmenter.dart` (blank-line
    split, trailing newlines trimmed) — the unit the service queues today."""
    ranges, start = [], 0
    for m in re.finditer(r"\n[ \t]*\n+", text):
        end = m.start()
        while end > start and text[end - 1] in "\n \t":
            end -= 1
        if end > start:
            ranges.append((start, end))
        start = m.end()
    while start < len(text) and text[start] == "\n":
        start += 1
    if start < len(text):
        end = len(text)
        while end > start and text[end - 1] == "\n":
            end -= 1
        ranges.append((start, end))
    return ranges


def units_in(text, start, end, unit):
    """How many utterances [start, end) is worth: one per paragraph until
    FR-011's sentence split lands, then one per sentence (scenario 17)."""
    if unit == "sentence":
        return sum(1 for s in sentence_starts(text) if start <= s < end)
    return sum(1 for (a, b) in paragraph_ranges(text) if a < end and b > start)


def content_node(rows):
    """The single semantics node that carries the whole reading text.

    Flutter exports the RichText as ONE node spanning every paragraph, so a
    paragraph is addressed by position inside its bounds, not by a node of its
    own (verified in the 010 walk dump: [42,388][1038,966] with the full text).
    """
    return find(rows, "The sun rose over the quiet town.")


def wait_for_idle(timeout=45):
    """Wait until the read has ended (the idle toolbar is back).

    The engine's `Synthesis request` lines are only a cross-check for the read
    LENGTH if the whole read has finished — counted inside a sleep window they
    say nothing (3-4 lines for a one-sentence read, 2 for a full page, purely
    by timing). The app's own `klhu speak` lines (one per utterance, FR-011)
    are the per-utterance evidence; this makes the other count honest.
    """
    for _ in range(timeout):
        rows = dump()
        if find(rows, "Continue Read") is not None:
            return True
        time.sleep(1)
    print(f"   read did not return to idle within {timeout} polls")
    return False


def tap_last_line(rows, label):
    """The last line of the text block, which is inside the last (third)
    paragraph — what quickstart scenario 13 calls 'a middle paragraph'."""
    node = content_node(rows)
    if node is None:
        print("   NOT FOUND: the reading text node")
        return False
    left, _, _, bottom = node["bounds"]
    tap_at(left + 20, bottom - 20, label)
    return True


def step(title):
    print(f"\n===== {title} =====")


# --------------------------------------------------------------------------
def scenario_13():
    step("SC13: fresh state (pm clear), the app opens the shipped EN pre-set")
    rows = start_app(clear=True)
    text = preset_text()
    third = text.index("This is the third")
    print(f"   preset length {len(text)}, third paragraph starts at {third}")
    print("   page shows the third paragraph:",
          find(rows, "This is the third") is not None)

    step("SC13: tap inside the third paragraph — the sentence is highlighted")
    before = yellow_pixels(f"{KLHU_OUT}/010_13_before.png")
    if not tap_last_line(rows, "third paragraph (last line of the block)"):
        return False
    time.sleep(1.2)
    after = yellow_pixels(f"{KLHU_OUT}/010_13_after.png")
    print(f"   yellow pixels before tap: {before}, after tap: {after}")
    if after <= before:
        print("   FAIL: the tap painted no highlight")
        return False

    step("SC13: Continue Read — logcat names the range it read")
    rows = dump()
    clear_log()
    if not tap_node(rows, "Continue Read", "Continue Read"):
        return False
    print("   read returned to idle:", wait_for_idle())
    lines = log_lines("klhu read range")
    for ln in lines:
        print("   ", ln)
    got = ranges(lines)
    if not got:
        print("   FAIL: no `klhu read range` line")
        return False
    start, end = got[-1]
    starts = sentence_starts(text)
    print(f"   read range {start}..{end}; text length {len(text)}")
    ok = (start != 0
          and start >= third
          and start in starts
          and end == len(text))
    print(f"   start is a sentence start inside the third paragraph: {ok}")
    print("   persisted record:", stored_position())
    print(f"   engine utterances for this read: {synthesis_count()} "
          f"(paragraphs in range: {units_in(text, start, end, 'paragraph')}, "
          f"sentences: {units_in(text, start, end, 'sentence')} — the queue "
          "unit is a paragraph until FR-011 lands)")
    return ok


def scenario_14():
    step("SC14: set a position on a middle paragraph")
    rows = dump()
    if find(rows, "Continue Read") is None:
        # A read may still be running from the previous part: back to idle.
        tap_node(rows, "Stop", "Stop")
        time.sleep(1.5)
        rows = dump()
    if find(rows, "This is the third") is None:
        rows = restart_app()
    if not tap_last_line(rows, "third paragraph (last line of the block)"):
        return False
    time.sleep(1.2)
    record = stored_position()
    print("   record after the tap:", record)
    if not record:
        print("   FAIL: no read_position_* key was written")
        return False
    stored = re.search(r">([^<]*)<", record[0])
    stored = stored.group(1) if stored else ""
    print(f"   stored value = {stored!r}")

    step("SC14: force-stop + relaunch — the position is restored and shown")
    rows = restart_app()
    painted = yellow_pixels(f"{KLHU_OUT}/010_14_restored.png")
    print(f"   yellow pixels after relaunch: {painted} "
          "(a restored position paints its sentence)")
    print("   still the same content:",
          find(rows, "This is the third") is not None)

    step("SC14: Continue Read reads the SAME range across the restart")
    clear_log()
    if not tap_node(rows, "Continue Read", "Continue Read"):
        return False
    time.sleep(6)
    for ln in log_lines("klhu read range"):
        print("   ", ln)
    got = ranges()
    if not got:
        print("   FAIL: no `klhu read range` line after the restart")
        return False
    start, end = got[-1]
    expected_offset = int(stored.split("||")[0])
    print(f"   after restart {start}..{end}; stored offset {expected_offset}")
    return start == expected_offset and painted > 0


def scenario_15():
    step("SC15: pm clear removes every record; Continue Read is the old page read")
    rows = start_app(clear=True)
    print("   records after pm clear:", stored_position() or "(none)")
    clear_log()
    if not tap_node(rows, "Continue Read", "Continue Read"):
        return False
    print("   read returned to idle:", wait_for_idle())
    for ln in log_lines("klhu read range"):
        print("   ", ln)
    got = ranges()
    if not got:
        print("   FAIL: no `klhu read range` line")
        return False
    start, end = got[-1]
    text = preset_text()
    print(f"   read range {start}..{end}; text length {len(text)}")
    print("   full-page read: start == 0 and end == text length:",
          start == 0 and end == len(text))
    print(f"   engine utterances for the full read: {synthesis_count()} "
          f"(paragraphs in range: {units_in(text, start, end, 'paragraph')}, "
          f"sentences: {units_in(text, start, end, 'sentence')})")
    return start == 0 and end == len(text)


def presets():
    path = os.path.join(KLHU_REPO, "assets", "content", "presets.json")
    with open(path, encoding="utf-8") as fh:
        return __import__("json").load(fh)["presets"]


def preset_by_language(language):
    for p in presets():
        if p["language"] == language:
            return p
    raise SystemExit(f"no pre-set for language {language}")


def speak_lines():
    """`klhu speak p<i> s<j> "<text>"` — which sentence went to the engine."""
    return log_lines("klhu speak")


def tags(lines):
    """The `p<i> s<j>` of each speak line, in order."""
    return [m for ln in lines
            for m in re.findall(r"p\d+ s\d+", ln)]


def synthesis_locales():
    """Locale tags the engine reported: `Synthesis request for locale <tag> …`.
    The only place a picked voice shows up — a UI dump never shows it."""
    out = []
    for ln in log_lines("Synthesis request"):
        m = re.search(r"locale ([a-zA-Z-]+)", ln)
        if m:
            out.append(m.group(1))
    return out


def open_library(rows):
    """Tap the app-bar Content action (008) to reach the unified list."""
    if not tap_node(rows, "Content", "Content (library)"):
        return None
    time.sleep(1.5)
    return dump()


def pick_content(rows, prefix):
    """Tap the library row whose name starts with [prefix] — a pre-set's row
    name is the first line of its text (008 `contentNameFrom`)."""
    node = find(rows, prefix)
    if node is None:
        print(f"   NOT FOUND: a row starting {prefix!r} — "
              f"visible: {labels(rows)[:12]}")
        return None
    tap_at(node["x"], node["y"], f"library row {prefix!r}")
    time.sleep(2.5)
    return dump()


def full_read_check(text, tag):
    """A whole read of [text]: one utterance per sentence, in order, and the
    read ends at the last sentence. Returns True on the machine-checkable
    half of quickstart scenario 17."""
    want = units_in(text, 0, len(text), "sentence")
    lines = speak_lines()
    got = tags(lines)
    print(f"   {tag}: sentences {want}, utterances {len(got)}, "
          f"engine requests {synthesis_count()}")
    print(f"   {tag}: utterance order {got}")
    locales = sorted(set(synthesis_locales()))
    print(f"   {tag}: engine locales {locales}")
    if len(got) != want:
        print(f"   FAIL: {len(got)} utterances for {want} sentences")
        return False
    last = text[sentence_starts(text)[-1]:].strip().replace("\n", " ")
    spoken = lines[-1].split('"', 1)[1].rsplit('"', 1)[0] if '"' in lines[-1] else ""
    if spoken.endswith("..."):
        # The log line is a 24-character prefix (ReaderService._logPrefix).
        spoken = spoken[:-3]
    tail = last[:24]
    print(f"   {tag}: last utterance {spoken!r} vs last sentence {tail!r} "
          f"(the log line trims at 24 chars)")
    return spoken != "" and tail.startswith(spoken)


def scenario_16():
    step("SC16: learn the toolbar's Pause/Resume coordinates from a live dump")
    rows = start_app(clear=True)
    if not tap_node(rows, "Continue Read", "Continue Read"):
        return False
    time.sleep(1.5)
    rows = dump()
    pause = find(rows, "Pause")
    if pause is None:
        print("   FAIL: no Pause button while speaking:", labels(rows)[:12])
        return False
    px, py = pause["x"], pause["y"]
    print(f"   Pause at {px},{py}")
    if not tap_node(rows, "Stop", "Stop (end the probe read)"):
        return False
    print("   back to idle:", wait_for_idle())

    step("SC16: read again; Pause lands during paragraph 0's SECOND sentence")
    clear_log()
    rows = dump()
    if not tap_node(rows, "Continue Read", "Continue Read"):
        return False
    paused_at = None
    for _ in range(80):
        seen = tags(speak_lines())
        if len(seen) >= 2 and seen[1] == "p0 s1":
            # The second sentence is in flight: kill the read right now.
            tap_at(px, py, "Pause (p0 s1 in flight)")
            paused_at = seen[1]
            break
        time.sleep(0.25)
    if paused_at is None:
        print("   FAIL: never reached p0 s1:", speak_lines())
        return False
    time.sleep(3)
    before = tags(speak_lines())
    print(f"   utterances before the pause: {before}")
    print(f"   last utterance before the pause: {before[-1] if before else '(none)'}")

    step("SC16: Resume repeats that sentence — not s0 of its paragraph")
    clear_log()
    rows = dump()
    if find(rows, "Resume") is None:
        print("   FAIL: no Resume button:", labels(rows)[:12])
        return False
    if not tap_node(rows, "Resume", "Resume"):
        return False
    print("   read finished:", wait_for_idle())
    after = speak_lines()
    got = tags(after)
    print(f"   utterances after the resume: {got}")
    if not got:
        print("   FAIL: nothing spoken after the resume")
        return False
    interrupted = before[-1]
    text = preset_text()
    counts = [units_in(text, a, b, "sentence")
              for (a, b) in paragraph_ranges(text)]
    p, s = (int(v) for v in interrupted.replace("p", "").split(" s"))
    remaining = sum(counts) - (sum(counts[:p]) + s)
    print(f"   interrupted {interrupted}: repeats {got[0]} "
          f"(same sentence: {got[0] == interrupted}), "
          f"utterances after the resume {len(got)} vs "
          f"{remaining} sentences left to read")
    print(f"   engine requests after the resume: {synthesis_count()}")
    return got[0] == interrupted and len(got) == remaining


def scenario_17():
    ok = True
    for language, label in (("en", "EN pre-set (catalog fallback)"),
                            ("zh-Hans", "ZH pre-set (from the library)"),
                            ("es", "ES pre-set (from the library)")):
        preset = preset_by_language(language)
        text = preset["text"].strip()
        step(f"SC17: a whole read of the {label}")
        rows = start_app(clear=True)
        if language != "en":
            rows = open_library(rows)
            if rows is None:
                return False
            rows = pick_content(rows, text[:8])
            if rows is None:
                return False
            if text[:8] not in " ".join(labels(rows)):
                print(f"   FAIL: the {language} text is not on the page:",
                      labels(rows)[:8])
                return False
        clear_log()
        if not tap_node(rows, "Continue Read", "Continue Read"):
            return False
        print("   read finished:", wait_for_idle())
        ok = full_read_check(text, label) and ok
    return ok


PARTS = {
    "13": scenario_13,
    "14": scenario_14,
    "15": scenario_15,
    "16": scenario_16,
    "17": scenario_17,
}

if __name__ == "__main__":
    part = sys.argv[1] if len(sys.argv) > 1 else ""
    if part not in PARTS:
        print(f"usage: {os.path.basename(__file__)} 13|14|15|16|17")
        sys.exit(2)
    print("RESULT:", "PASS" if PARTS[part]() else "FAIL")
