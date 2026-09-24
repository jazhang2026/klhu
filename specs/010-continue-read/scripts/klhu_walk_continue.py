#!/usr/bin/env python3
"""klhu device walk — spec 010 quickstart, scenarios 13-15 (Continue Read).

What each part proves, and with which evidence line:

  13  a tap on a middle paragraph sets the start position, and Continue Read
      reads from there          -> `klhu read range: <start>..<end>` in logcat
                                   (+ a yellow-pixel count before/after the tap)
  14  the position survives a restart -> the `read_position_*` record in
                                   FlutterSharedPreferences.xml, then the same
                                   range again after a force-stop + relaunch
  15  no position -> the previous behaviour, unchanged
                                -> `klhu read range: 0..<len>` after `pm clear`

Usage:
    python3 klhu_walk_continue.py 13|14|15

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


def preset_text():
    """The shipped EN pre-set, straight out of the asset the app ships."""
    path = os.path.join(KLHU_REPO, "assets", "content", "presets.json")
    with open(path, encoding="utf-8") as fh:
        data = __import__("json").load(fh)
    for p in data["presets"]:
        if p["id"] == "preset_en_sample":
            return p["text"]
    raise SystemExit("preset_en_sample missing from the catalog")


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


def content_node(rows):
    """The single semantics node that carries the whole reading text.

    Flutter exports the RichText as ONE node spanning every paragraph, so a
    paragraph is addressed by position inside its bounds, not by a node of its
    own (verified in the 010 walk dump: [42,388][1038,966] with the full text).
    """
    return find(rows, "The sun rose over the quiet town.")


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
    if not tap_node(rows, "Continue Read", "Continue Read"):
        return False
    time.sleep(6)
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
    print("   engine utterances for this read:", synthesis_count())
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
    time.sleep(8)
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
    print("   engine utterances for the full read:", synthesis_count())
    return start == 0 and end == len(text)


PARTS = {"13": scenario_13, "14": scenario_14, "15": scenario_15}

if __name__ == "__main__":
    part = sys.argv[1] if len(sys.argv) > 1 else ""
    if part not in PARTS:
        print(f"usage: {os.path.basename(__file__)} 13|14|15")
        sys.exit(2)
    print("RESULT:", "PASS" if PARTS[part]() else "FAIL")
