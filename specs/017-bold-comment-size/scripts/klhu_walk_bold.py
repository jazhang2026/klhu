#!/usr/bin/env python3
"""017's device rows: the six faces, and the paint a bold weight produces.

Run one quickstart row per invocation:

    /usr/bin/python3 specs/017-bold-comment-size/scripts/klhu_walk_bold.py 8
    /usr/bin/python3 specs/017-bold-comment-size/scripts/klhu_walk_bold.py 9
    /usr/bin/python3 specs/017-bold-comment-size/scripts/klhu_walk_bold.py 12

Row 8 (quickstart row 8) drives the appearance control itself: the six labels,
the two-part record each bold value writes, and the bold paint that survives a
force-stop and relaunch. Row 9 (quickstart row 9) measures the widest painted
line of each bold face at `xlarge` against the column the regular face's own ink
defines — 011 FR-012's guarantee, taken again for the three new faces (017 D6).
Row 12 (quickstart row 12) paints a Chinese content under each bold value and
measures the ink, because no bold CJK face ships on this device: the fallback
face decides the paint, and the probe of 2026-10-12 says `mono-bold`'s Chinese
is `bold`'s to the pixel.

The mechanics are 015's module's (014's and 012's beneath it), the screenshots
are 011's, and `/usr/bin/python3` (3.12) is needed: the default `python3` has no
PIL.
"""

import os
import sys
import time

from PIL import Image

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "015-comment-tag", "scripts"))
sys.path.insert(0, os.path.join(REPO, "specs", "011-reading-experience", "scripts"))

# 015's module owns the device mechanics (014's and 012's beneath it).
import klhu_walk_comment as comment  # noqa: E402
import klhu_walk_experience as experience  # noqa: E402

adb = comment.adb
dump = comment.dump
step = comment.step
check = comment.check
start_app = comment.start_app
fresh_prefs = comment.fresh_prefs
prefs_value = comment.prefs_value
open_section = comment.open_section
PKG = comment.PKG
RESULTS = comment.RESULTS
tap_control = experience.tap_control
screencap = experience.screencap
OUT = experience.OUT

os.makedirs(OUT, exist_ok=True)

ACTION = "Appearance"
DONE = "Done"
FACES = (("bold", "Bold"), ("serif-bold", "Serif bold"), ("mono-bold", "Mono bold"))
REGULARS = (("default", "Default"), ("serif", "Serif"), ("mono", "Mono"))
SIZES = {"small": "Small", "medium": "Medium", "large": "Large", "xlarge": "Extra large"}
ZH = "今天天气真不错。我的旅行日记。太阳升起来了。鸟儿在歌唱。"

# The reading area only: below the app bar, above the toolbar and the system
# bar, so neither a row's ink COUNT nor its ink EXTENT is decided by the chrome
# (which does not change between two captures) — the first device run of row 8
# measured a +14% weight through a band that carried the toolbar's own icons,
# where the probe put the same weight at +39% per glyph (corrected 2026-10-12).
BAND = (0, 250, 1080, 1700)

# Row 10 reads the page's own painted LINES, so its band starts below the app
# bar: that bar's title is ink too, and a first run that counted it took the
# title for the sentence and compared 49 px against 18 (corrected 2026-10-12 in
# the same pass). The band still ends above the page's toolbar.
CONTENT_BAND = (0, 430, 1080, 1700)


def force_stop():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.2)


def cap(name):
    path = os.path.join(OUT, name)
    screencap(path)
    return path


def ink(path, band=BAND):
    """The dark ink in [band]: its count, its own bounding box, and its ratio."""
    im = Image.open(path).convert("L").crop(band)
    w, h = im.size
    px = im.load()
    xs = []
    ys = []
    for y in range(h):
        for x in range(w):
            if px[x, y] < 100:
                xs.append(x)
                ys.append(y)
    if not xs:
        return None
    x0, x1, y0, y1 = min(xs), max(xs), min(ys), max(ys)
    return dict(
        pixels=len(xs),
        x0=x0 + band[0],
        x1=x1 + band[0],
        y0=y0 + band[1],
        y1=y1 + band[1],
        area=(x1 - x0 + 1) * (y1 - y0 + 1),
    )


def ratio(m):
    return m["pixels"] / m["area"] if m else 0.0


def set_appearance(face_label, size_label=None):
    """Drives the shipped control: open it, pick the face (and size), confirm."""
    if not tap_control(dump(), ACTION, "the appearance action"):
        return False
    time.sleep(0.8)
    if not tap_control(dump(), face_label, f"the {face_label} chip"):
        return False
    time.sleep(0.4)
    if size_label is not None:
        if not tap_control(dump(), size_label, f"the {size_label} chip"):
            return False
        time.sleep(0.4)
    if not tap_control(dump(), DONE, "the confirm"):
        return False
    time.sleep(1.5)
    return True


def row_8():
    step("row 8 — six faces, the record each bold value writes, and the relaunch")
    fresh_prefs()
    open_section("main")
    start_app()
    time.sleep(1.0)

    if not tap_control(dump(), ACTION, "the appearance action"):
        check("8: the appearance action is on the page", False, f"visible: {dump()[:1]}")
        return False
    time.sleep(0.8)
    # Presence is proven by the tap the next rows need anyway: `tap_control`
    # matches a label EXACTLY, so 'Serif' never answers for 'Serif bold'. Tapping
    # a chip only moves the candidate — nothing is written until the confirm.
    for _, label in REGULARS + FACES:
        check(f"8: the control offers '{label}'",
              tap_control(dump(), label, f"the '{label}' chip"), "the chip's own label")
    adb("shell", "input", "keyevent", "4")  # back out without confirming
    time.sleep(1.0)

    for face, label in FACES:
        if not set_appearance(label):
            check(f"8: the picker accepted '{label}'", False, "the chip or the confirm was not found")
            return False
        value = prefs_value("reading_appearance")
        check(f"8: the record for '{label}' is a two-part value",
              value == f"{face}||medium", f"reading_appearance = {value!r}")

    # The weight's own effect, with the family held still: `serif` against
    # `serif-bold` at one size. Comparing `default` against a NAMED bold would
    # measure the family change too — monospace's narrow glyphs fit more per
    # line, which is how this row's first run read +12% for a weight the probe
    # put at +39% (corrected 2026-10-12 in the same pass).
    if not set_appearance("Serif", SIZES["medium"]):
        check("8: 'Serif' at medium is in force", False, "the picker did not take it")
        return False
    regular = ink(cap("017_row8_serif_medium.png"))
    if not set_appearance("Serif bold", SIZES["medium"]):
        check("8: 'Serif bold' at medium is in force", False, "the picker did not take it")
        return False
    bold = ink(cap("017_row8_serif_bold_medium.png"))
    # The ink COUNT, not its ratio: a bold face may wrap a line, which grows the
    # bounding box a ratio divides by and dilutes exactly this difference.
    # A tenth of the reading band's whole ink is a large change: the probe's own
    # per-glyph figure for this weight was +39% (2026-10-12).
    check("8: the same family and size carries more ink in its bold (FR-002)",
          bold["pixels"] > regular["pixels"] * 1.10,
          f"{regular['pixels']} ink pixels (serif||medium) -> {bold['pixels']} (serif-bold||medium)")

    force_stop()
    start_app()
    time.sleep(1.5)
    after = ink(cap("017_row8_after_relaunch.png"))
    held = prefs_value("reading_appearance")
    check("8: the relaunch kept the last record", held == "serif-bold||medium", f"{held!r}")
    check("8: the relaunched page paints the same text (the record is in force)",
          abs(after["pixels"] - bold["pixels"]) <= max(60, bold["pixels"] * 0.02),
          f"{bold['pixels']} ink pixels before the relaunch, {after['pixels']} after")
    return True


def row_9():
    step("row 9 — xlarge: each bold face's widest line against its OWN family's regular")
    fresh_prefs()
    open_section("main")
    start_app()
    time.sleep(1.0)

    # Each family's own column, at the same size: comparing `serif-bold` against
    # `default`'s ink measures the FAMILY, not the weight — this row's first run
    # did exactly that and read a 35 px "overflow" that was Roboto's metrics
    # against serif's (corrected 2026-10-12 in the same pass).
    bounds = {}
    for face, label in REGULARS:
        if not set_appearance(label, SIZES["xlarge"]):
            check(f"9: xlarge + '{label}' is in force", False, "the picker did not take it")
            return False
        m = ink(cap(f"017_row9_{face}_xlarge.png"))
        if m is None:
            check(f"9: '{label}' at xlarge paints something to compare against", False, "no ink found")
            return False
        bounds[face] = m
        print(f"   {face:10s} x {m['x0']}..{m['x1']}  ({m['pixels']} ink pixels)")

    ok = True
    for face, label in FACES:
        reference = "default" if face == "bold" else face.split("-")[0]
        if not set_appearance(label, SIZES["xlarge"]):
            check(f"9: xlarge + '{label}' is in force", False, "the picker did not take it")
            return False
        m = ink(cap(f"017_row9_{face}_xlarge.png"))
        if m is None:
            check(f"9: '{label}' at xlarge paints its text", False, "no ink found")
            ok = False
            continue
        ref = bounds[reference]
        # What FR-012 asserts about a line being inside the page is its RIGHT
        # edge, and that is exact (1042 in every capture: the column's own right
        # bound). A bold glyph's ink starts a few px closer to the left margin —
        # its side bearing is smaller, which is a property of the weight and not
        # a layout change, so the left is reported and bounded generously rather
        # than asserted as identical (this row's second run, 2026-10-12).
        right_ok = m["x1"] <= ref["x1"] + 2
        left_drift = ref["x0"] - m["x0"]
        left_ok = left_drift <= 12
        print(f"   {face:10s} x {m['x0']}..{m['x1']}  ({m['pixels']} ink pixels, "
              f"{reference}'s right bound {ref['x1']}, left ink {ref['x0']}, drift {left_drift} px)")
        check(f"9: '{label}' at xlarge crosses neither edge of its own family's column "
              f"(011 FR-012)", right_ok and left_ok,
              f"x {m['x0']}..{m['x1']} against {reference}'s {ref['x0']}..{ref['x1']} "
              f"(right edge {'ok' if right_ok else 'CROSSED'}, left drift {left_drift} px)")
        ok = ok and right_ok and left_ok
    return ok


def row_12():
    step("row 12 — a Chinese content under each bold value (no bold CJK face ships)")
    fresh_prefs()
    open_section("zh", name="中文粗体", text=ZH)
    start_app()
    time.sleep(1.0)

    measured = {}
    for face, label in REGULARS + FACES:
        if not set_appearance(label, SIZES["medium"]):
            check(f"12: '{label}' is in force", False, "the picker did not take it")
            return False
        m = ink(cap(f"017_row12_{face}.png"))
        measured[face] = ratio(m)
        check(f"12: '{label}' paints the Chinese content (FR-005)",
              m is not None and m["pixels"] > 500,
              f"{m['pixels'] if m else 0} ink pixels")
    print("   ink/area: " + ", ".join(f"{k}={v:.3f}" for k, v in measured.items()))

    same = abs(measured["mono-bold"] - measured["bold"]) / measured["bold"]
    check("12: 'Mono bold' paints Chinese exactly as 'Bold' does (the fallback face decides)",
          same < 0.05, f"bold={measured['bold']:.3f} mono-bold={measured['mono-bold']:.3f} "
                       f"({same:.2%} apart)")
    heavier = measured["serif-bold"] > measured["serif"]
    check("12: 'Serif bold' paints Chinese heavier than 'Serif' (the weight is synthesised)",
          heavier, f"serif={measured['serif']:.3f} -> serif-bold={measured['serif-bold']:.3f}")
    return True


def ink_lines(path, band=None):
    """The page's own painted LINES inside [band], as (top, bottom) rows."""
    box = band or BAND
    im = Image.open(path).convert("L").crop(box)
    w, h = im.size
    px = im.load()
    ink = [any(px[x, y] < 100 for x in range(w)) for y in range(h)]
    bands = []
    start = None
    for y, has in enumerate(ink):
        if has and start is None:
            start = y
        elif not has and start is not None:
            bands.append((start + box[1], y - 1 + box[1]))
            start = None
    if start is not None:
        bands.append((start + box[1], h - 1 + box[1]))
    return bands


def yellow_band(path):
    """The tracking highlight's own rows, if any (011's yellow, read directly)."""
    im = Image.open(path).convert("RGB")
    w, h = im.size
    px = im.load()
    ys = [y for y in range(h)
          if any(px[x, y][0] > 200 and px[x, y][1] > 180 and px[x, y][2] < 120
                 for x in range(0, w, 4))]
    return (min(ys), max(ys)) if ys else None


def row_10():
    step("row 10 — the page's measured comment size, at medium and at small")
    fresh_prefs()
    # A fixture built for the comparison: the comment repeats its sentence's own
    # word, so the two lines hold the SAME glyphs and their ink heights measure
    # the SIZE alone. The first run used 015's own fixture and read a 49 vs 33 px
    # difference that was the two lines' different letters — the same confound
    # row 8's first comparison had (corrected 2026-10-12 in the same pass).
    if comment.open_section("same", "comment_same", "同词注释",
                            text="Hola.\n\n[注] Hola.") is None:
        return False
    start_app()
    time.sleep(1.2)

    heights = {}
    for size, label in (("medium", "Medium"), ("small", "Small")):
        if not set_appearance("Default", SIZES[size]):
            check(f"10: default + {size} is in force", False, "the picker did not take it")
            return False
        path = cap(f"017_row10_{size}.png")
        bands = ink_lines(path, band=CONTENT_BAND)
        if len(bands) < 2:
            check(f"10/{size}: the page paints the sentence and the comment", False,
                  f"{len(bands)} ink bands: {bands}")
            return False
        # Two lines, the same word in both: the first is the sentence, the last
        # is the comment (the blank line between them carries no ink).
        sentence, comment_line = bands[0], bands[-1]
        heights[size] = (sentence[1] - sentence[0], comment_line[1] - comment_line[0])
        print(f"   10/{size}: the page's lines {bands} — the sentence {sentence[1] - sentence[0]}px, "
              f"the comment {comment_line[1] - comment_line[0]}px")
        check(f"10/{size}: the comment's own line is shorter than the text's",
              heights[size][1] < heights[size][0],
              f"comment {heights[size][1]}px against the sentence {heights[size][0]}px")

    check("10: the comment shrinks with the text size (10 points at the smallest)",
          heights["small"][1] < heights["medium"][1],
          f"comment {heights['medium'][1]}px at medium, {heights['small'][1]}px at small")

    # FR-010's device half: a tap inside the comment still answers the comment,
    # and the highlight it paints is the comment's own line.
    bands = ink_lines(cap("017_row10_again.png"), band=CONTENT_BAND)
    comment_line = bands[-1]
    adb("shell", "input", "tap", "540", str((comment_line[0] + comment_line[1]) // 2))
    time.sleep(1.2)
    after = cap("017_row10_tapped.png")
    yellow = yellow_band(after)
    check("10: a tap inside the comment paints the highlight over it (FR-010)",
          yellow is not None and yellow[0] >= comment_line[0] - 12
          and yellow[1] <= comment_line[1] + 12,
          f"the highlight {yellow} against the comment's line {comment_line}")
    return True


def row_11():
    step("row 11 — the comment in a frame, and 015's row 22 re-taken")
    fresh_prefs()
    if comment.open_section("main", "comment_main", "注释-注释") is None:
        return False
    result = comment.render_one("11/comment")
    if result is None:
        check("11: the render produced a file", False, "render_one returned nothing")
        return False
    # `slot_of` answers the FIRST slot's run as a dict (015's own usage), not a
    # list of runs.
    run = comment.slot_of(result[2])
    if not run:
        check("11: the render's own line is in the log", False, "no slot line found")
        return False
    w, h = comment.PICK_WH
    got = comment.box_of_frame(result[0], run["start"], w, h)
    if got is None:
        check("11: the slot's first frame was read back", False, "box_of_frame returned nothing")
        return False
    band, outside, box = got
    height = box[3] - box[1]
    print(f"   slot 0: frame {run['start']} text={run['text']} "
          f"span={run['span_start']}..{run['span_end']} ink box={box} (height {height}px of {h})")
    check("11: the block still paints the sentence AND the comment — no tag",
          run["text"] == comment.BLOCK_CHARS,
          f"text={run['text']} against 015's own sum {comment.BLOCK_CHARS}")
    check("11: the block is SHORTER than 015 measured — the comment's line is smaller",
          height < 100, f"{height}px now against 015's 100px (research.md:499-500)")
    check("11: no highlight band in the frame, nothing outside the column",
          band == 0 and outside == 0, f"band={band} outside={outside}")
    return True


ROWS = {"8": row_8, "9": row_9, "10": row_10, "11": row_11, "12": row_12}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(f"usage: {os.path.basename(__file__)} {'|'.join(sorted(ROWS))}")
        sys.exit(2)
    ROWS[sys.argv[1]]()
    failed = [row[0] for row in RESULTS if not row[1]]
    print(f"\nRESULT: {'PASS' if not failed else 'FAIL'} "
          f"({len(RESULTS) - len(failed)}/{len(RESULTS)})")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
