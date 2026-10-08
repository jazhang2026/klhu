#!/usr/bin/env python3
"""A second keep with the review's replacement switch off (012 FR-012's amendment,
2026-10-06).

What the row shows: the review asks the question only when the content already has
a video, the offered answer is the shipped rule (replace), and turning it off
leaves the earlier file in the library beside the new one while the content's own
record comes to point at the render just kept.

    ADB_SERIAL=38821a76 KLHU_ASPECT='9:16 vertical (Shorts)' \
        python3 klhu_walk_replace_switch.py

The phone is NOT cleared: this row needs a content that already has a kept video,
so it works on whatever the app is showing. `KLHU_ASPECT` must be the wording the
device's own format prompt uses.
"""

import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import klhu_walk_video as v  # the driver's device mechanics: dump/labels/tap

DEV = os.environ.get("ADB_SERIAL", "38821a76")
ASPECT = os.environ.get("KLHU_ASPECT", "9:16 vertical (Shorts)")
PKG = "com.example.klhu"
ALBUM = "/storage/emulated/0/Movies/Klhu"
WAIT_REVIEW = 600  # the render is ~140 s on the reader's phone; generous for a slow one
WAIT_SETTLE = 150  # the platform finishes a replacement's own delete after the fact

v.DEV = DEV


def shell(*args):
    return subprocess.run(
        ["adb", "-s", DEV, *args], capture_output=True, text=True
    ).stdout


def window_xml():
    shell("shell", "rm", "-f", "/sdcard/switch_dump.xml")
    shell("shell", "uiautomator", "dump", "/sdcard/switch_dump.xml")
    return shell("exec-out", "cat", "/sdcard/switch_dump.xml")


def album():
    # One name per line: a library name may itself contain a space.
    out = shell("shell", "ls", "-1", ALBUM)
    return sorted(
        line.strip() for line in out.splitlines() if line.strip().endswith(".mp4")
    )


def record_ids():
    """Every media id the app's own records hold, whatever the content.

    The prefs file is XML: its JSON values arrive with their quotes escaped. The
    row compares the *set* before and after, so it does not need to know which
    entry belongs to the content in force.
    """
    xml = shell(
        "shell", "run-as", PKG, "cat",
        f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml",
    ).replace("&quot;", '"')
    return {int(m) for m in re.findall(r'"uri":"[^"]*?/(\d+)"', xml)}


def switch():
    """(offered, checked, box) for the review's replacement switch."""
    xml = window_xml()
    for m in re.finditer(r"<node[^>]*>", xml):
        n = m.group(0)
        if 'class="android.widget.Switch"' in n or 'checkable="true"' in n:
            checked = re.search(r'checked="([^"]*)"', n)
            box = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
            return (
                True,
                (checked.group(1) == "true" if checked else None),
                tuple(map(int, box.groups())) if box else None,
            )
    return False, None, None


def wait_for(label, seconds, what):
    deadline = time.time() + seconds
    while time.time() < deadline:
        if label in v.labels(v.dump()):
            return True
        time.sleep(3)
    print(f"FAIL: {what} did not arrive within {seconds}s")
    return False


def main():
    before = album()
    before_ids = record_ids()
    print(f"before: {len(before)} file(s) in the album, records {sorted(before_ids)}")
    for name in before:
        print(f"  {name}")

    shell("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(4)
    rows = v.dump()
    print("page labels:", v.labels(rows)[:12])

    if not v.tap(rows, "Video", label="the video action"):
        return print("FAIL: the video action was not offered")
    time.sleep(2)
    rows = v.dump()
    print("prompt labels:", v.labels(rows)[:10])
    if not v.tap(rows, ASPECT, exact=True, label=f"the format {ASPECT!r}"):
        return print("FAIL: the format was not offered")
    time.sleep(1)
    rows = v.dump()
    if not v.tap(rows, "Start", label="Start"):
        return print("FAIL: the render could not be started")

    if not wait_for("Save", WAIT_REVIEW, "the review"):
        return
    rows = v.dump()
    print("review labels:", v.labels(rows)[:8])
    offered, checked, box = switch()
    print(f"the replacement switch: offered={offered} checked={checked}")
    if not offered:
        return print("FAIL: the review did not ask about replacing")
    if checked is not True:
        return print(f"FAIL: the offered answer is not the shipped rule (checked={checked})")
    if box is None:
        return print("FAIL: the switch has no box to tap")

    x1, y1, x2, y2 = box
    shell("shell", "input", "tap", str((x1 + x2) // 2), str((y1 + y2) // 2))
    time.sleep(2)
    offered, checked, _ = switch()
    print(f"after the tap: offered={offered} checked={checked}")
    if checked is not False:
        return print("FAIL: the switch did not turn off")

    rows = v.dump()
    if not v.tap(rows, "Save", label="Save"):
        return print("FAIL: the review could not be saved")
    time.sleep(WAIT_SETTLE)

    after = album()
    after_ids = record_ids()
    print(f"after: {len(after)} file(s) in the album, records {sorted(after_ids)}")
    for name in after:
        print(f"  {name}")

    kept = [name for name in before if name in after]
    added = [name for name in after if name not in before]
    arrived = after_ids - before_ids
    left = before_ids - after_ids
    ok = (
        len(kept) == len(before)
        and len(added) == 1
        and len(arrived) == 1
        and len(left) == 1
    )
    print(f"the earlier file(s) kept: {kept}")
    print(f"the render just kept: {added}")
    print(f"the record moved to it: {sorted(arrived)} in, {sorted(left)} out")
    print("RESULT:", "PASS" if ok else "FAIL")


if __name__ == "__main__":
    main()
