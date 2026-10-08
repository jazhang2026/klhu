#!/usr/bin/env python3
"""What the reading page's top bar holds, in each orientation, on a real phone.

011 FR-025: portrait gives the actions a row of their own under the brand and the
language; landscape keeps the shipped single row. The bar's own controls need
more than a portrait window has, so a squeezed or clipped action is the defect
this reports on (it was): measured on the reader's phone 2026-10-06, the shipped
row left the brand zero width, squeezed Play video to 16 dp and pushed Share and
Delete video off the edge.

    python3 klhu_toolbar_geometry.py <serial>
"""

import re
import statistics
import subprocess
import sys
import time

DEV = sys.argv[1] if len(sys.argv) > 1 else "38821a76"
PKG = "com.example.klhu"

# The bar's own band: its row is 48 dp tall, so in a portrait window of
# 1080x2376 (density 3) the whole bar sits inside the top ~400 px.
BAND = 400

ACTIONS = [
    "Appearance",
    "Contents",
    "Text type",
    "Voice",
    "Video",
    "Play video",
    "Share",
    "Delete video",
]


def adb(*args):
    return subprocess.run(
        ["adb", "-s", DEV, *args], capture_output=True, text=True
    ).stdout


def dump():
    for _ in range(3):
        adb("shell", "rm", "-f", "/sdcard/window_dump.xml")
        adb("shell", "uiautomator", "dump", "/sdcard/window_dump.xml")
        xml = adb("exec-out", "cat", "/sdcard/window_dump.xml")
        if "<node" in xml:
            return xml
        time.sleep(1)
    raise SystemExit("the window could not be dumped")


def bar():
    """(the window's width now, the labelled nodes in the top band)."""
    xml = dump()
    window = re.search(r'bounds="\[0,0\]\[(\d+),(\d+)\]"', xml)
    width = int(window.group(1)) if window else 1080
    nodes = []
    for m in re.finditer(r"<node[^>]*>", xml):
        n = m.group(0)
        lab = re.search(r'content-desc="([^"]*)"', n) or re.search(
            r'text="([^"]*)"', n
        )
        b = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if not (lab and b and lab.group(1).strip()):
            continue
        x1, y1, x2, y2 = map(int, b.groups())
        # The bar's own rows: its controls are one row tall (48 dp = 144 px
        # here), which is what keeps the reading text below the band out.
        if y1 < BAND and (y2 - y1) <= 160:
            nodes.append((x1, x2, y1, y2, lab.group(1).strip()[:24]))
    return width, sorted(nodes)


def report(tag):
    width, nodes = bar()
    print(f"########## {tag} (window {width} px wide) ##########")
    rows = {}
    for x1, x2, y1, y2, lab in nodes:
        rows.setdefault((y1, y2), []).append((x1, x2, lab))
    for (y1, y2), items in sorted(rows.items()):
        print(f"  row y{y1}-{y2}:")
        for x1, x2, lab in items:
            print(f"    x{x1:5d}-{x2:5d} (w{x2 - x1:4d})  {lab!r}")
    return width, rows


def verdict(width, rows, *, own_row, expect_actions):
    """The contract: the actions sit where this orientation says they do, and
    every one of them is whole and inside the window."""
    labels = {
        lab: (x1, x2)
        for items in rows.values()
        for x1, x2, lab in items
        if lab != "English" and "KalaHoo" not in lab
    }
    actions = {lab: xy for lab, xy in labels.items() if lab in expect_actions}
    unexpected = [lab for lab in labels if lab not in expect_actions]
    widths = [x2 - x1 for x1, x2 in actions.values()]
    median = statistics.median(widths) if widths else 0
    squeezed = [
        lab for lab, (x1, x2) in actions.items() if median and x2 - x1 < 0.9 * median
    ]
    past = [lab for lab, (x1, x2) in actions.items() if x2 > width]
    missing = [lab for lab in expect_actions if lab not in actions]
    language_bands = [
        band
        for band, items in rows.items()
        if any(lab == "English" for _, _, lab in items)
    ]
    action_bands = sorted(
        {
            band
            for band, items in rows.items()
            if any(lab in expect_actions for _, _, lab in items)
        }
    )
    shared = any(band == action for band in language_bands for action in action_bands)
    print(f"  language row {language_bands}, actions row {action_bands}")
    print(
        f"  the actions have a row of their own: {not shared} "
        f"(this orientation wants: {own_row})"
    )
    print(
        f"  squeezed: {squeezed or 'none'}; past the edge: {past or 'none'}; "
        f"missing: {missing or 'none'}; unexpected: {unexpected or 'none'}"
    )
    return (
        not squeezed
        and not past
        and not missing
        and not unexpected
        and (not shared) == own_row
    )


def rotate(landscape):
    adb("shell", "settings", "put", "system", "accelerometer_rotation", "0")
    adb("shell", "settings", "put", "system", "user_rotation",
        "1" if landscape else "0")
    time.sleep(3)


def main():
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(4)

    rotate(landscape=False)
    width, portrait = report("PORTRAIT")
    portrait_ok = verdict(width, portrait, own_row=True, expect_actions=ACTIONS)

    rotate(landscape=True)
    width, landscape = report("LANDSCAPE")
    landscape_ok = verdict(width, landscape, own_row=False, expect_actions=ACTIONS)

    rotate(landscape=False)
    print()
    print("PASS" if portrait_ok and landscape_ok else "FAIL")


if __name__ == "__main__":
    main()
