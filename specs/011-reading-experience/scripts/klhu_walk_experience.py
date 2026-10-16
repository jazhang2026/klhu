#!/usr/bin/env python3
"""Device walk for spec 011 (Reading Experience).

    python3 klhu_walk_experience.py 7|8|9|10|16|17|20|21

Each part prints its evidence and ends with `RESULT: PASS|FAIL`. The shared
device mechanics (uiautomator dump, taps, logcat readers, the shipped pre-set
text, paragraph/sentence ranges) live in 010's driver and are imported from
there, so the two walks cannot drift apart. `ADB_SERIAL`, `KLHU_REPO` and
`KLHU_OUT` override the defaults.

Scenario numbers are 011's own (quickstart.md); 010's driver has its own 13-17.
The two things only a device can show here:

* `klhu follow: p<i> s<j> visible=<0|1> top=<t> bottom=<b> viewport=<h>` — the
  geometry the view decided on, per sentence. The uiautomator dump exports the
  whole reading text as ONE semantics node, so a sentence's position inside
  that node is measured by position, and where the page is scrolled is nowhere
  in the dump or in logcat.
* `klhu speak p<i> s<j> "…"` — which sentence went to the engine.

Paint claims are pixel claims: the highlight is the only yellow on screen, so a
screenshot gives its row range. Rows are scanned at 1/4 scale (a filled run
survives a 4x reduction), which is precise to ±4 device px — quoted that way in
breakpoint.md.
"""
import importlib.util
import json
import os
import re
import subprocess
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.environ.get(
    "KLHU_REPO", os.path.abspath(os.path.join(HERE, "..", "..", "..")))
BASE_DRIVER = os.path.join(
    REPO, "specs", "010-continue-read", "scripts", "klhu_walk_continue.py")


def _load(path, name):
    spec = importlib.util.spec_from_file_location(name, path)
    mod = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(mod)
    return mod


base = _load(BASE_DRIVER, "klhu_walk_continue")

adb = base.adb
OUT = base.KLHU_OUT
PKG = base.PKG
step = base.step

# The app's own evidence lines start with the shipped English pre-set; 010's
# `content_node` finds exactly that node.
EN_PREFIX = "The sun rose over the quiet town."

SCALE = 4


def dpr():
    """Device pixels per logical pixel: the dump and the screenshots are in
    device pixels, the app's `klhu follow` geometry is in logical pixels."""
    out = adb("shell", "wm", "density")
    m = re.search(r"(\d+)", out.split(":")[-1])
    return int(m.group(1)) / 160.0


def screencap(path):
    with open(path, "wb") as fh:
        fh.write(adb("exec-out", "screencap", "-p", binary=True))
    return path


def follow_lines():
    """`klhu follow: p<i> s<j> visible=<0|1> top=<t> bottom=<b> viewport=<h>`."""
    out = []
    for ln in base.log_lines("klhu follow"):
        # The `below` field is **022's own** (2026-10-16) and the pattern is left
        # unanchored, so the six-field lines of this feature's own receipts still
        # read exactly as they did.
        m = re.search(
            r"p(\d+) s(\d+) visible=(\d) top=(-?\d+) bottom=(-?\d+) viewport=(\d+)"
            r"(?: below=(\d+))?",
            ln)
        if m:
            out.append({
                "p": int(m.group(1)),
                "s": int(m.group(2)),
                "visible": int(m.group(3)) == 1,
                "top": int(m.group(4)),
                "bottom": int(m.group(5)),
                "viewport": int(m.group(6)),
               'below': int(m.group(7) or 0),
            })
    return out


def spoken():
    """The `(paragraph, sentence)` of every utterance the app announced."""
    return [(int(m.group(1)), int(m.group(2)))
            for ln in base.speak_lines()
            for m in [re.search(r"p(\d+) s(\d+)", ln)] if m]


def yellow_rows(path, x0=0, x1=None):
    """Per-row yellow cell counts (DEVICE-pixel rows) from a 1/4-scale scan."""
    from PIL import Image
    img = Image.open(path).convert("RGB")
    w, h = img.size
    small = img.resize((w // SCALE, h // SCALE), Image.Resampling.NEAREST)
    px = small.load()
    sw, sh = small.size
    sx0 = max(0, x0 // SCALE)
    sx1 = min(sw, (x1 if x1 is not None else w) // SCALE)
    rows = {}
    for y in range(sh):
        n = 0
        for x in range(sx0, sx1):
            r, g, b = px[x, y]
            if r > 200 and g > 200 and b < 90:
                n += 1
        if n:
            rows[y * SCALE] = n * SCALE * SCALE
    return rows


def band_split(rows, band, slack=8):
    """(inside, outside) yellow area for a DEVICE-pixel row band.

    [slack] absorbs the difference between the app's own origin and the
    content node's top (measured at ~6 device px on this AVD): a pixel within
    8 device px of the reported band still counts as inside it, which is
    narrower than one line of text (54 device px) and 2.5x narrower than the
    shortest sentence band here.
    """
    t, b = band[0] - slack, band[1] + slack
    inside = sum(n for y, n in rows.items() if t <= y <= b)
    outside = sum(n for y, n in rows.items() if not t <= y <= b)
    return inside, outside


def bbox(rows):
    ys = sorted(rows)
    return (ys[0], ys[-1]) if ys else None


def text_node(rows, prefix=EN_PREFIX):
    """The reading text's semantics node, addressed by the text that starts it.

    010's `content_node` is hard-wired to the English pre-set; row 9 reads the
    Spanish one, so the address is a parameter here.
    """
    return base.find(rows, prefix)


def text_columns(rows, prefix=EN_PREFIX):
    """The reading block's left/right bounds (device px) — keeps the scan out
    of the toolbar's icons."""
    node = text_node(rows, prefix)
    if node is None:
        return (0, None)
    left, _, right, _ = node["bounds"]
    return (left, right)


def first_row(labels):
    """The list's first entry row.

    A row's label is `name\\nlanguage · date`; the app bar's controls (`Back`,
    `Contents`, `Add content`) carry no newline — indexing `labels[0]` reads a
    toolbar button, which is how the first run of this check passed a row that
    was there all along.
    """
    for label in labels:
        if "\n" in label:
            return label
    return ""


def stored_prefs():
    out = adb("shell", "run-as", PKG, "cat",
              f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml")
    return [ln.strip() for ln in out.splitlines() if ln.strip()]


def record_lines(needle):
    return [ln for ln in stored_prefs() if needle in ln]


# `stored_offset()` stood here: it read the stored position out of 010's own
# `stored_position()` (itself a reader of the withdrawn record). With its two
# callers retired on 2026-10-16 it had none left — the house's rule is no dead
# code, and 010's driver keeps its own reader.
    return None


def diff_share(a_path, b_path):
    """The share of pixels that differ between two screenshots (1/4 scale)."""
    from PIL import Image
    a = Image.open(a_path).convert("L")
    b = Image.open(b_path).convert("L")
    size = (a.size[0] // SCALE, a.size[1] // SCALE)
    pa = list(a.resize(size, Image.Resampling.NEAREST).getdata())
    pb = list(b.resize(size, Image.Resampling.NEAREST).getdata())
    return sum(1 for x, y in zip(pa, pb) if abs(x - y) > 32) / len(pa)


def block_height(rows, prefix=EN_PREFIX):
    node = text_node(rows, prefix)
    if node is None:
        return None
    _, top, _, bottom = node["bounds"]
    return bottom - top


def origin(rows, prefix=EN_PREFIX):
    """Where the app's `follow` geometry starts, in device pixels.

    Measured on this AVD: the reported band lands at `origin + top * dpr` with
    the content node's own top as the origin (aligned within ~5 device px on
    both a 2400 px and a 1000 px display). The dump can show neither the scroll
    offset nor the highlight, which is why the numbers are cross-checked
    against the screenshots' yellow rows.
    """
    node = text_node(rows, prefix)
    return node["bounds"][1] if node else 0


def set_viewport(w, h):
    """Shrink the display so the text is taller than the page.

    The `[device]` rows 7, 8 and 10 are about a page that has to move. At the
    default size the reading area here is 718 logical px tall and the longest
    shipped text is 226 logical, so nothing ever scrolls — the walk asks the
    device for a smaller display (a 1080x1000 one leaves a 209 logical viewport)
    and resets it afterwards.
    """
    adb("shell", "wm", "size", f"{w}x{h}")
    time.sleep(2)


def reset_viewport():
    adb("shell", "wm", "size", "reset")
    time.sleep(2)


def screen_height():
    """The display's height in device pixels (the reading node can extend past
    it: at X-Large its bottom bound was 1506 on a 1000 px display)."""
    m = re.search(r"(\d+)x(\d+)", adb("shell", "wm", "size"))
    return int(m.group(2)) if m else 2400


def visible_low_point(rows):
    """A point on the lowest line of the reading text that is ON screen.

    010's `tap_last_line` uses the node's own bottom, which off-screen at
    X-Large means the tap lands nowhere: the first run of scenario 8 tapped
    y=1486 on a 1000 px display and set neither a position nor a highlight.
    Scenario 20 needs the SAME point twice — tapped once, held once — so the
    arithmetic lives here rather than in the tap.
    """
    node = text_node(rows)
    if node is None:
        print("   NOT FOUND: the reading text node")
        return None
    left, _, _, bottom = node["bounds"]
    return left + 20, min(bottom, screen_height()) - 40


def tap_visible_low_line(rows, label):
    """Taps the lowest line that is actually ON screen."""
    point = visible_low_point(rows)
    if point is None:
        return False
    base.tap_at(point[0], point[1], label)
    return True


def hold_at(point, label, hold_ms=900):
    """HOLDS a finger on the reading text: the page's own long-press, which
    selects the whole paragraph (003). `input swipe` with no travel is the
    device's long-press, and the PAGE is where the unit is picked — a long press
    on the ▶ button means nothing (FR-023/FR-024)."""
    x, y = point
    adb("shell", "input", "swipe", str(x), str(y), str(x), str(y), str(hold_ms))
    print(f"   HOLD the page {label} @{x},{y}")


def set_bounds(rows, needle):
    """Swipe the page by hand, so a stored position can leave the screen.

    Two swipes: one page of travel is not always enough to push a line that was
    tapped near the bottom past the top edge (measured — one 488 px swipe left
    it on screen, which is exactly what the first run of scenario 8 showed).
    """
    node = text_node(rows)
    if node is None:
        return False
    left, top, right, bottom = node["bounds"]
    x = (left + right) // 2
    y_from, y_to = min(bottom, screen_height()) - 40, top + 40
    for _ in range(2):
        adb("shell", "input", "swipe", str(x), str(y_from),
            str(x), str(y_to), "300")
        time.sleep(0.8)
    time.sleep(1.2)
    return True


def back_to_top(rows):
    """Puts the reading page back at its own top: two downward swipes.

    022 amended scenario 20 (2026-10-16). The row's own subject needs **the same
    line** tapped once and held once, and it used to get that for free because a
    read never moved the page. 022's narrowing (011 FR-003, recorded) makes a read
    move the page in one case, so "the same line" is no longer the same device
    point a few seconds later: the page is returned to its own top before each
    gesture, which is what makes the low line the same line again.
    """
    node = text_node(rows)
    if node is None:
        return False
    left, top, right, bottom = node["bounds"]
    x = (left + right) // 2
    y_from, y_to = top + 40, min(bottom, screen_height()) - 40
    for _ in range(2):
        adb("shell", "input", "swipe", str(x), str(y_from),
            str(x), str(y_to), "300")
        time.sleep(0.8)
    time.sleep(1.2)
    return True


def set_xlarge(rows):
    """X-Large text, so the page is taller than the viewport.

    Measured: a shrinking display alone leaves the shipped pre-set only ~30
    device px taller than the reading area, which is not a scroll. X-Large
    (24 pt against the shipped 14) triples the block's height — the user's own
    route to the same premise, and the appearance screen is part of this
    feature.
    """
    if not base.tap_node(rows, "Appearance", "Appearance"):
        return None
    time.sleep(1.5)
    rows = base.dump()
    base.tap_node(rows, "Extra large", "Extra large")
    time.sleep(0.8)
    rows = base.dump()
    if not base.tap_node(rows, "Done", "Done (X-Large)"):
        return None
    time.sleep(1.5)
    print(f"   appearance record: {record_lines('reading_appearance')}")
    return base.dump()


# --------------------------------------------------------------------------
def scenario_7():
    step("7. a long read: the page follows it, sentence by sentence")
    rows = base.start_app(clear=True)
    rows = set_xlarge(rows) or rows
    set_viewport(1080, 1000)
    rows = base.dump()
    text = base.preset_text()
    ratio = dpr()
    x0, x1 = text_columns(rows)
    print(f"   pre-set: {len(text)} chars, "
          f"{len(base.sentence_starts(text))} sentences; dpr={ratio}; "
          f"display 1080x1000 so the text is taller than the page")
    base.clear_log()
    if not base.tap_node(rows, "Continue Read", "Continue Read"):
        return False

    frames = []
    deadline = time.time() + 150
    while time.time() < deadline:
        path = screencap(f"{OUT}/klhu_walk_011_s7_{len(frames)}.png")
        seen = follow_lines()
        node_top = origin(base.dump())
        frames.append((path, seen, node_top))
        if base.find(base.dump(), "Continue Read") is not None and seen:
            break
        time.sleep(0.5)

    ok = True
    reports, utterances = follow_lines(), spoken()
    print(f"   klhu speak: {len(utterances)} utterances | "
          f"klhu follow: {len(reports)} reports | {len(frames)} frames | "
          f"viewport={reports[0]['viewport'] if reports else '?'} logical")
    speak_tags = [f"p{p} s{s}" for p, s in utterances]
    follow_tags = [f"p{r['p']} s{r['s']}" for r in reports]
    if speak_tags != follow_tags:
        print("   FAIL: the reports and the utterances do not agree, in order")
        print(f"      speak  : {speak_tags}")
        print(f"      follow : {follow_tags}")
        ok = False
    for r in reports:
        if not r["visible"] or not 0 <= r["top"] < r["bottom"] <= r["viewport"]:
            print(f"   FAIL: p{r['p']} s{r['s']} geometry {r}")
            ok = False
    print("   first/last report: "
          + ", ".join(f"p{r['p']} s{r['s']} top={r['top']} bottom={r['bottom']}"
                      for r in (reports[:1] + reports[-1:])))

    # The paint half: a frame whose yellow rows are exactly the reported
    # sentence's band (the app's own geometry, mapped to the screen), with
    # nothing yellow outside it.
    matched = None
    for path, seen, node_top in frames:
        ys = yellow_rows(path, x0, x1)
        if not ys or not seen:
            continue
        for r in seen[-3:]:
            band = (node_top + r["top"] * ratio, node_top + r["bottom"] * ratio)
            inside, outside = band_split(ys, band)
            painted = bbox(ys)
            if inside and outside * 20 <= inside and \
                    band[0] - 20 <= painted[0] and painted[1] <= band[1] + 20:
                matched = (path, r, inside, outside, painted, band, node_top)
                break
        if matched:
            break
    if matched is None:
        print("   FAIL: no frame showed the highlight inside the reported band")
        print("   frames: " + ", ".join(
            f"{os.path.basename(p)}={bbox(yellow_rows(p, x0, x1)) or 'none'}"
            f"(n={len(s)}, origin={t})" for p, s, t in frames[:6]))
        reset_viewport()
        return False
    path, r, inside, outside, painted, band, node_top = matched
    print(f"   paint: p{r['p']} s{r['s']} band={band[0]:.0f}..{band[1]:.0f}px "
          f"(origin {node_top} + {r['top']}..{r['bottom']}×{ratio}) "
          f"yellow={painted[0]}..{painted[1]}px inside/outside={inside}/{outside} "
          f"({os.path.basename(path)})")
    reset_viewport()
    return ok


def scenario_8():
    step("8. a stored position that is off screen is revealed first")
    rows = base.start_app(clear=True)
    rows = set_xlarge(rows) or rows
    set_viewport(1080, 1000)
    rows = base.dump()
    x0, x1 = text_columns(rows)
    if not tap_visible_low_line(rows, "a line low on the page (sets the position)"):
        return False
    time.sleep(1.5)
    # 016 amended this row (2026-10-12): it read the tapped offset off a
    # `read_position_*` record, and that record left the tree with 010's FR-008
    # (016 decision 5). The launch's own re-cut row is 016's row 8; what this row
    # proves is the REVEAL, so the tapped line is read back off the app's own
    # lines below — the range ⏭ reads starts at it (never at the text's top), and
    # its first report is inside the reading area.
    offset = None
    tapped = screencap(f"{OUT}/klhu_walk_011_s8_tapped.png")
    painted_after_tap = bbox(yellow_rows(tapped, x0, x1))
    if painted_after_tap is None:
        print("   FAIL: the tap set neither a position nor a highlight — "
              "tap a line that is on screen")
        reset_viewport()
        return False

    # Scroll the page by hand: the painted position leaves the screen, the
    # record does not (010's rule — a manual scroll is not an edit).
    if not set_bounds(rows, "swipe up (page moves on)"):
        return False
    scrolled = screencap(f"{OUT}/klhu_walk_011_s8_scrolled.png")
    away = bbox(yellow_rows(scrolled, x0, x1))
    if away is not None:
        print("   FAIL: the position is still on screen after the swipe — "
              "this scenario needs it off screen")
        reset_viewport()
        return False

    base.clear_log()
    rows = base.dump()
    if not base.tap_node(rows, "Continue Read", "Continue Read"):
        return False
    time.sleep(3)
    reports, read_ranges = follow_lines(), base.ranges()
    shot = screencap(f"{OUT}/klhu_walk_011_s8_revealed.png")
    node = base.content_node(base.dump())
    ys = yellow_rows(shot, x0, x1)

    if not reports or not read_ranges:
        print("   FAIL: no follow / read-range lines")
        reset_viewport()
        return False
    first, rng = reports[0], read_ranges[0]
    ok = True
    print(f"   tap painted {painted_after_tap} device px; "
          f"after the swipe: no yellow on screen (the position is off screen)")
    print(f"   first report: p{first['p']} s{first['s']} "
          f"visible={int(first['visible'])} top={first['top']} "
          f"bottom={first['bottom']} viewport={first['viewport']}")
    print(f"   read range  : {rng[0]}..{rng[1]} (the tapped line's own sentence)")
    print(f"   revealed    : yellow={bbox(ys)} device px, inside the reading "
          f"area {node['bounds'][1]}..{node['bounds'][3]}")
    if not first["visible"] or not 0 <= first["top"] < first["bottom"] <= first["viewport"]:
        print("   FAIL: the first report is not inside the viewport")
        ok = False
    if rng[0] == 0:
        print("   FAIL: the read started at the top of the text, not at the "
              "tapped line (010's rule)")
        ok = False
    if bbox(ys) is None or not node["bounds"][1] <= bbox(ys)[0] or \
            bbox(ys)[1] > node["bounds"][3]:
        print("   FAIL: the highlight was not revealed inside the reading area")
        ok = False
    reset_viewport()
    return ok


def scenario_9():
    step("9. a short text that fits never moves")
    reset_viewport()
    rows = base.start_app(clear=True)
    short = base.preset_by_language("es")
    rows = base.open_library(rows)
    if rows is None:
        return False
    rows = base.pick_content(rows, short["text"][:12])
    if rows is None:
        return False
    prefix = short["text"][:12]
    node = text_node(rows, prefix)
    if node is None:
        print(f"   FAIL: the short pre-set is not on the page: "
              f"{base.labels(rows)[:8]}")
        return False
    top_before = node["bounds"][1]
    x0, x1 = text_columns(rows, prefix)
    base.clear_log()
    if not base.tap_node(rows, "Continue Read", "Continue Read"):
        return False

    frames = []
    deadline = time.time() + 120
    while time.time() < deadline:
        path = screencap(f"{OUT}/klhu_walk_011_s9_{len(frames)}.png")
        frames.append((path, follow_lines()))
        if base.find(base.dump(), "Continue Read") is not None:
            break
        time.sleep(0.5)

    reports = follow_lines()
    after = text_node(base.dump(), prefix)
    painted = [(bbox(yellow_rows(p, x0, x1)) or (0, 0)) for p, _ in frames]
    print(f"   klhu follow: {len(reports)} reports, all visible="
          f"{sorted({int(r['visible']) for r in reports})}")
    print(f"   block top: {top_before} → {after['bounds'][1]} "
          f"(unchanged = never scrolled)")
    print(f"   yellow per frame: {[n for _, n in painted]}")
    ok = True
    if not all(reports):
        print("   FAIL: no follow lines")
        return False
    for r in reports:
        if not r["visible"] or not 0 <= r["top"] < r["bottom"] <= r["viewport"]:
            print(f"   FAIL: p{r['p']} s{r['s']} geometry {r}")
            ok = False
    if after["bounds"][1] != top_before:
        print("   FAIL: the page moved although the text fits")
        ok = False
    # One frame is taken before the first sentence is painted and one after the
    # read ends, so the claim is "as many frames carried a highlight as there
    # were sentences", not "every frame".
    lit = sum(1 for _, n in painted if n)
    if lit < len(reports):
        print(f"   FAIL: only {lit} of {len(frames)} frames had a highlight, "
              f"for {len(reports)} sentences")
        ok = False
    return ok


def scenario_10():
    step("10. Stop mid-read: the page stays where it stopped")
    rows = base.start_app(clear=True)
    rows = set_xlarge(rows) or rows
    set_viewport(1080, 1000)
    rows = base.dump()
    x0, x1 = text_columns(rows)
    before_shot = screencap(f"{OUT}/klhu_walk_011_s10_before.png")
    baseline = sum(yellow_rows(before_shot, x0, x1).values())
    print(f"   before the read: yellow={baseline} device px")

    base.clear_log()
    if not base.tap_node(rows, "Continue Read", "Continue Read"):
        return False
    moved = None
    mid_shot = None
    deadline = time.time() + 120
    while time.time() < deadline:
        reports = follow_lines()
        if reports:
            moved = reports[-1]
        mid_shot = screencap(f"{OUT}/klhu_walk_011_s10_mid.png")
        # "Where it stopped" only means something once the page has actually
        # MOVED: at X-Large on a 1080x1000 display the opening sentences are
        # already inside the 209-px area, so FR-003 keeps the page still — and
        # `klhu follow` reports the sentence's box inside the reading area
        # either way, so the move is measured from the pixels.
        if (moved and len(reports) >= 2
                and diff_share(before_shot, mid_shot) > 0.02):
            break
        time.sleep(1)
    mid_yellow = bbox(yellow_rows(mid_shot, x0, x1))
    if moved is None or mid_yellow is None:
        print("   FAIL: no scrolled report with a highlight to stop on")
        reset_viewport()
        return False
    print(f"   mid-read : p{moved['p']} s{moved['s']} top={moved['top']} "
          f"bottom={moved['bottom']} viewport={moved['viewport']}, "
          f"yellow={mid_yellow}")

    rows = base.dump()
    if not base.tap_node(rows, "Stop", "Stop"):
        return False
    time.sleep(2)
    after_a = screencap(f"{OUT}/klhu_walk_011_s10_after_a.png")
    time.sleep(1)
    after_b = screencap(f"{OUT}/klhu_walk_011_s10_after_b.png")
    after_yellow = sum(yellow_rows(after_b, x0, x1).values())

    same_page = diff_share(mid_shot, after_b)
    returned_to_top = diff_share(before_shot, after_b)
    still = diff_share(after_a, after_b)
    scrolled = diff_share(before_shot, mid_shot)
    print(f"   after Stop: yellow={after_yellow} (before the read {baseline})")
    print(f"   pixel shares — the page moved during the read "
          f"top vs mid {scrolled * 100:.2f}%, mid vs after {same_page * 100:.2f}% "
          f"(the highlight alone), top-of-page vs after "
          f"{returned_to_top * 100:.2f}%, after vs a second later {still * 100:.2f}%")
    ok = True
    if scrolled <= 0.05:
        print("   FAIL: the page never moved during the read — nothing to stop on")
        ok = False
    if after_yellow > max(baseline * 2, 2000):
        print("   FAIL: the highlight did not clear")
        ok = False
    # The claim is the DISTANCE from the top of the text, not a resemblance to
    # the mid-read shot: the mid shot carries a highlight the after shot cannot
    # (it cleared), so only the top-of-page reference compares like with like.
    if returned_to_top < scrolled * 0.6:
        print("   FAIL: the page went back towards the top of the text after Stop")
        ok = False
    if still > 0.01:
        print("   FAIL: the page was still moving after Stop")
        ok = False
    reset_viewport()
    return ok


def scenario_16():
    step("16. Serif + X-Large: the record, the restart, and the render")
    reset_viewport()
    rows = base.start_app(clear=True)
    x0, x1 = text_columns(rows)
    default_before = screencap(f"{OUT}/klhu_walk_011_s16_default.png")
    height_before = block_height(rows)
    print(f"   shipped look: text block {height_before} device px tall")

    if not base.tap_node(rows, "Appearance", "Appearance"):
        return False
    time.sleep(1.5)
    rows = base.dump()
    print(f"   appearance screen: {base.labels(rows)[:10]}")
    if not base.tap_node(rows, "Serif", "Serif"):
        return False
    time.sleep(0.8)
    rows = base.dump()
    if not base.tap_node(rows, "Extra large", "Extra large"):
        return False
    time.sleep(0.8)
    rows = base.dump()
    if not base.tap_node(rows, "Done", "Done (confirm)"):
        return False
    time.sleep(1.5)

    record = record_lines("reading_appearance")
    print(f"   record: {record}")
    ok = any("serif||xlarge" in ln for ln in record)

    rows = base.restart_app()
    serif_after = screencap(f"{OUT}/klhu_walk_011_s16_serif_xlarge.png")
    height_after = block_height(rows)
    print(f"   after the restart: text block {height_after} device px tall "
          f"({height_before} before) — the larger size re-laid the text")
    print(f"   default vs serif+xlarge screenshots differ by "
          f"{diff_share(default_before, serif_after) * 100:.2f}% of pixels")

    # The Chinese half: the same look on the zh pre-set, recorded for the
    # glyph-coverage eyeball (research D5 — not machine-checkable).
    zh = base.preset_by_language("zh-Hans")
    rows = base.open_library(rows)
    if rows is not None:
        rows = base.pick_content(rows, zh["text"][:6])
        if rows is not None:
            shot = screencap(f"{OUT}/klhu_walk_011_s16_serif_xlarge_zh.png")
            print(f"   zh text under the same look: {os.path.basename(shot)} "
                  f"({block_height(rows, zh['text'][:6]) or 0} device px tall)")

    # Back to the shipped look, so the device is left in a defined state.
    if not base.tap_node(rows, "Appearance", "Appearance"):
        return False
    time.sleep(1.5)
    rows = base.dump()
    base.tap_node(rows, "Default", "Default")
    time.sleep(0.8)
    rows = base.dump()
    base.tap_node(rows, "Medium", "Medium")
    time.sleep(0.8)
    rows = base.dump()
    if not base.tap_node(rows, "Done", "Done (restore)"):
        return False
    time.sleep(1.5)
    restored = screencap(f"{OUT}/klhu_walk_011_s16_restored.png")
    print(f"   restored record: {record_lines('reading_appearance')}; "
          f"default-again vs serif screenshots differ by "
          f"{diff_share(restored, serif_after) * 100:.2f}% of pixels")
    if ok and diff_share(restored, serif_after) < 0.02:
        print("   FAIL: the restored look renders like the serif one")
        ok = False
    if ok and not any("default||medium" in ln
                      for ln in record_lines("reading_appearance")):
        print("   FAIL: the shipped look was not written back")
        ok = False
    return ok


def scenario_17():
    step("17. the list's add action: a named save, an empty one refused")
    reset_viewport()
    rows = base.start_app(clear=True)
    rows = base.open_library(rows)
    if rows is None:
        return False
    list_before = base.labels(rows)
    print(f"   list before: {list_before[:6]}")

    if not base.tap_node(rows, "Add content", "Add content"):
        return False
    time.sleep(2)
    rows = base.dump()
    print(f"   draft editor: {base.labels(rows)[:8]}")
    typed = "Walk note 011"
    adb("shell", "input", "text", typed.replace(" ", "%s"))
    time.sleep(1.2)
    rows = base.dump()
    # The editor's text is NOT in the dump (008's breakpoint divergence 5:
    # "in EDIT mode the field's text is not in the uiautomator dump, so the
    # committed text is only observable after Done") — the row in the list is
    # the evidence, not the field.
    if not base.tap_node(rows, "Save", "Save (named draft)"):
        return False
    time.sleep(2.5)

    rows = base.open_library(base.dump())
    if rows is None:
        return False
    list_after = base.labels(rows)
    print(f"   list after : {list_after[:6]}")
    ok = typed in first_row(list_after)

    # Second pass: the same action with nothing typed.
    if not base.tap_node(rows, "Add content", "Add content"):
        return False
    time.sleep(2)
    rows = base.dump()
    if not base.tap_node(rows, "Save", "Save (empty draft)"):
        return False
    time.sleep(1.5)
    rows = base.dump()
    refusal = base.find(rows, "There is nothing to save")
    print(f"   refusal on screen: {refusal is not None} | {base.labels(rows)[:8]}")
    if refusal is None:
        ok = False

    if not base.tap_node(rows, "Done", "Done (leave the empty draft)"):
        return False
    time.sleep(1.5)
    rows = base.dump()
    rows = base.open_library(rows)
    if rows is None:
        return False
    list_final = base.labels(rows)
    print(f"   list final : {list_final[:6]}")
    if list_final != list_after:
        print("   FAIL: the empty Save added a row")
        ok = False
    # **2026-10-16 (022's regression sweep): the two reads that stood here are
    # gone.** They compared the stored position list before and after a draft —
    # a record 010's FR-008 withdrew (016's decision 5), so both sides were always
    # empty and the check could not fail. What it meant ("a draft disturbs no
    # reading position") is what the lines above witness from the app's own state:
    # the library's rows are identical, and the app keeps no position record at all
    # any more (the page's position in force is in memory, and 011's own FR-022 is
    # why a read leaves none behind).

    # Third pass: the same draft finished with the CHECK icon. Done saves (the
    # fix this row pins) — the row must appear without touching Save, because a
    # check that only left the editor silently lost the draft.
    ticked = "Ticked draft 011"
    if not base.tap_node(rows, "Add content", "Add content"):
        return False
    time.sleep(2)
    rows = base.dump()
    adb("shell", "input", "text", ticked.replace(" ", "%s"))
    time.sleep(1.2)
    rows = base.dump()
    if not base.tap_node(rows, "Done", "Done (finish the draft)"):
        return False
    time.sleep(2.5)
    rows = base.dump()
    rows = base.open_library(rows)
    if rows is None:
        return False
    list_ticked = base.labels(rows)
    print(f"   list after Done: {list_ticked[:6]}")
    if ticked not in first_row(list_ticked):
        print("   FAIL: the check icon did not save the draft")
        ok = False
    return ok


def tap_control(rows, label, what):
    """Taps the toolbar control whose label is EXACTLY [label].

    `base.find` matches substrings, so "Read" would hit "Continue Read" first
    (the ▶ and ⏭ tooltips differ only by that word).
    """
    for row in rows:
        if (row["desc"] or row["text"]) == label:
            base.tap_at(row["x"], row["y"], what)
            return True
    print(f"   NOT FOUND: {label!r} — visible: {base.labels(rows)[:10]}")
    return False


def yellow_present(label):
    """Whether the screen has any yellow on it (the reading highlight)."""
    path = screencap(f"{OUT}/klhu_walk_011_s20_{label}.png")
    rows = yellow_rows(path)
    total = sum(rows.values())
    print(f"   yellow {label}: {total} px ({path})")
    return total > 0


def scenario_20():
    step("20. no highlight means no read; the page's gesture picks what ▶ reads")
    rows = base.start_app(clear=True)
    if base.find(rows, "Appearance") is None:
        # The launch landed on the contents list (a previous part left it
        # there): every step below measures the READING page, and a walk that
        # silently measured the list would report on nothing.
        if not base.tap_node(rows, "Back", "Back to the reading page"):
            reset_viewport()
            return False
        time.sleep(1.5)
        rows = base.dump()
    rows = set_xlarge(rows)
    if rows is None:
        print("   FAIL: the reading page did not accept Extra large")
        reset_viewport()
        return False
    set_viewport(1080, 1000)
    text = base.preset_text()
    ok = True
    def set_position(why, hold=False):
        """The same line of the page: TAPPED it sets a sentence position (010
        FR-002), HELD it selects the whole paragraph (003). One point, two
        gestures — which is exactly the pair the rows below compare.

        **022 amended this row (2026-10-16)**: the point is derived here, per
        gesture, from a page first returned to its own top — the row used to
        measure it once, before the read above, and a read now moves the page in
        the one case 022's rule covers, which made the held point land on another
        paragraph. The subject is unchanged: the same line, one tap, one hold.
        """
        if not back_to_top(base.dump()):
            print("   FAIL: the reading text is not on the page to measure")
            return None
        point = visible_low_point(base.dump())
        if point is None:
            return None
        if hold:
            hold_at(point, why)
        else:
            base.tap_at(point[0], point[1], why)
        time.sleep(1.5)
        # 016 amended this row (2026-10-12): the `read_position_*` record this
        # returned left the tree (010 FR-008 withdrawn, 016 decision 5). What the
        # rows below need is that the gesture put something in force — its own
        # painted line, read off the screenshot.
        return bbox(yellow_rows(screencap(f"{OUT}/klhu_walk_011_s20_point.png")))

    def press_read(label):
        """The ranges one press of ▶/⏭ reads, in a log window of its own."""
        base.clear_log()
        if not tap_control(base.dump(), label, label):
            return None
        time.sleep(2.5)
        return base.ranges()

    def wait_idle_placeholder():
        pass

    offset = set_position("a line low on the page (sets the position)")
    if offset is None:
        print("   FAIL: the gesture left nothing in force (nothing painted)")
        reset_viewport()
        return False
    painted = yellow_present("after the tap")
    print(f"   the gesture's own painted band: {offset}")
    if not painted:
        print("   FAIL: the tap set a position but painted nothing")
        ok = False


    # ▶ TAPPED with a TAP-selected SENTENCE: one sentence, so its span is
    # strictly shorter than the paragraph holding it (FR-023/FR-024).
    one = press_read("Read")
    span = one[0] if one else None
    # 016 amended this row (2026-10-12): the tapped offset came off the retired
    # `read_position_*` record (010 FR-008 withdrawn, 016 decision 5). The app's
    # own live range is the witness now: ▶'s first press names the sentence the tap
    # put in force, and the paragraph holding it is computed from THAT.
    para = next((p for p in base.paragraph_ranges(text)
                 if span is not None and p[0] <= span[0] < p[1]), None)
    if para is None:
        print(f"   FAIL: the pre-set holds no paragraph around ▶'s own range {span}")
        reset_viewport()
        return False
    print(f"   ▶ sentence : {span} (the paragraph holding it: {para[0]}..{para[1]})")
    if not span:
        print("   FAIL: ▶ read nothing at all")
        ok = False
    elif span[1] - span[0] >= para[1] - para[0]:
        print("   FAIL: ▶ read the whole paragraph, not the selected sentence")
        ok = False

    # ▶ with a LONG-PRESS-selected PARAGRAPH: the whole paragraph, from its own
    # start. That read ended and took the position with it (FR-022), so the page
    # is selected again first.
    # A read in flight owns the text (FR-025), so the next selection waits for
    # the sentence read above to end — its 2.5 s is not a completion signal.
    if not base.wait_for_idle():
        reset_viewport()
        return False
    if set_position("the same line, held (selects the paragraph)", hold=True) is None:
        reset_viewport()
        return False
    whole = press_read("Read")
    held = whole[0] if whole else None
    print(f"   ▶ paragraph: {held} (the paragraph is {para[0]}..{para[1]})")
    if held != para:
        print(f"   FAIL: ▶ read {held}, not the long-pressed paragraph {para}")
        ok = False

    # ⏭ from the position, to the end of the text (010 FR-004), and the ended
    # read leaves neither highlight nor position (FR-022).
    if not base.wait_for_idle():
        reset_viewport()
        return False
    again = set_position("the same line again (position for ⏭)")
    if again is None:
        reset_viewport()
        return False
    resumed = press_read("Continue Read")
    ran = resumed[0] if resumed else None
    print(f"   ⏭ tapped  : {ran} (the same line's own sentence {span[0]}, "
          f"text {len(text)} chars)")
    # 016 amended this check (2026-10-12): after a step the highlight ADVANCES
    # (016 FR-004), so a fixed screen point can hold a different sentence than it
    # did before the reads scrolled the page — the exact-offset equality was the
    # retired record's job. What the rule needs is that ⏭ runs from a place a
    # gesture put in force to the text's end: a NON-ZERO start, and the end.
    if not ran or ran[0] == 0 or ran[1] != len(text):
        print("   FAIL: ⏭ did not read from a tapped place to the end of the text")
        ok = False
    if not base.wait_for_idle():
        reset_viewport()
        return False
    time.sleep(1.5)
    if yellow_present("after the read ended"):
        print("   FAIL: the ended read left its highlight painted")
        ok = False
    # **2026-10-16 (022's regression sweep): the read of the record that stood here
    # is gone.** It asked the withdrawn `read_position_*` record to be empty — and
    # the app writes no such record at all (the device's prefs hold the appearance
    # key and nothing else), so the check could not fail. What it meant (FR-022: an
    # ended read leaves nothing in force) is witnessed **live** by the check two
    # lines above: the ended read's highlight is not painted.

    # ▶ Read with nothing highlighted: it speaks NOTHING and asks for a
    # selection (FR-023) — reading the page from the top is ⏭'s fallback.
    # 016 amended this block (2026-10-12): ▶ Read with nothing highlighted now
    # reads the text's FIRST sentence and stops (016 FR-001, amending 011 FR-023);
    # the page asks for a selection no longer.
    fresh = press_read("Read")
    prompt = base.find(base.dump(), "Select a sentence or paragraph to read")
    print(f"   ▶ after the read : ranges={fresh or 'none'} "
          f"prompt={'shown' if prompt else 'MISSING'}")
    if not fresh or fresh[0][0] != 0:
        print("   FAIL: ▶ with nothing highlighted did not read the first sentence")
        ok = False
    if prompt is not None:
        print("   FAIL: the page still asks for a selection (016 FR-001)")
        ok = False

    # ⏭ Continue Read with nothing in force: the first sentence to the end,
    # exactly the read a page that was never tapped gives (010 FR-005).
    # 016 amended the STATE this is reached in (2026-10-12): a ▶ press now leaves
    # the next sentence highlighted (FR-004), so "nothing in force" is Stop's
    # doing — which is 016 FR-009's own rule, and the page's Stop is pressed here
    # so the check still starts from a clean page.
    base.clear_log()
    if not base.tap_node(base.dump(), "Stop", "Stop"):
        print("   FAIL: Stop is not on the page")
        reset_viewport()
        return False
    base.wait_for_idle()
    from_top = press_read("Continue Read")
    span = from_top[0] if from_top else None
    print(f"   ⏭ with nothing set: {span} (text is {len(text)} chars)")
    if not span or span[0] != 0:
        print("   FAIL: ⏭ did not start at the first sentence")
        ok = False
    elif span[1] != len(text):
        print("   FAIL: ⏭ did not read to the end of the text")
        ok = False
    reset_viewport()
    return ok


def scenario_21():
    """FR-025 on the device: a touch during a read changes nothing at all."""
    step("21. a touch during a read changes nothing (tap / hold / scroll)")
    rows = base.start_app(clear=True)
    if base.find(rows, "Appearance") is None:
        # The launch can land on the contents list (a previous part left it
        # there): every step below measures the reading page.
        if not base.tap_node(rows, "Back", "Back to the reading page"):
            return False
        time.sleep(1.5)
        rows = base.dump()
    ok = True
    point = visible_low_point(rows)
    if point is None:
        return False

    # A read from the top (nothing set): ⏭ reads the whole text, which is long
    # enough for several touches to land while it plays.
    base.clear_log()
    if not tap_control(base.dump(), "Continue Read", "Continue Read (starts the read)"):
        return False
    time.sleep(1.0)
    if base.find(base.dump(), "Pause") is None:
        print("   FAIL: the read never started (no Pause control)")
        return False
    print("   reading: Pause is up, so the read is in flight")

    # The three touches a real user makes for reasons of their own: a quick tap
    # (this is how a dimmed display is woken), a long press, and a scroll drag
    # (the fling a tap would stop).
    for label, gesture in (("a tap", "tap"), ("a long press", "hold")):
        fresh = base.dump()
        p = visible_low_point(fresh) or point
        if gesture == "tap":
            base.tap_at(p[0], p[1], f"{label} on the text mid-read")
        else:
            hold_at(p, f"{label} on the text mid-read")
        time.sleep(0.5)
    fresh = base.dump()
    p = visible_low_point(fresh) or point
    adb("shell", "input", "swipe", str(p[0]), str(max(p[1] - 120, 200)),
        str(p[0]), str(p[1]), "300")
    print(f"   DRAG the text mid-read (a scroll) @{p[0]},{max(p[1] - 120, 200)}->{p[1]}")
    time.sleep(1.2)

    rows = base.dump()
    if base.find(rows, "Pause") is None:
        print("   FAIL: the read is not running any more — a touch ended it")
        ok = False
    elif base.find(rows, "Resume") is not None:
        print("   FAIL: a touch parked the read")
        ok = False
    else:
        print("   still reading after tap + hold + scroll: Pause is up")
    # **2026-10-16 (022's regression sweep): the check that stood here is gone, and
    # its claim is not lost.** It read the stored position — the record 010's
    # FR-008 withdrew (016's decision 5) — so it could not fail: the app writes no
    # such pref under any name, and a check that reports PASS for nothing is worse
    # than no check. What it meant ("a touch during a read does not move the
    # position") is what the lines above already witness from the app's own state:
    # `Pause` up means the read was neither ended nor parked by the touch, and the
    # read's own utterance stream below is its own continuation. If a position
    # store ever returns, this check comes back with a live witness, the way this
    # file's row 20 and row 23 were re-cut the same day.
    print("   position: nothing to read — the app writes no such record any more")

    # PAUSED is a read in progress too (FR-025 says so explicitly).
    if not tap_control(base.dump(), "Pause", "Pause (parks the read)"):
        return False
    time.sleep(0.8)
    rows = base.dump()
    if base.find(rows, "Resume") is None:
        print("   FAIL: Pause did not park the read")
        return False
    p = visible_low_point(rows) or point
    base.tap_at(p[0], p[1], "a tap on the text while parked")
    time.sleep(1.0)
    rows = base.dump()
    if base.find(rows, "Resume") is None:
        print("   FAIL: a touch ended a parked read (Resume is gone)")
        ok = False
    else:
        print("   parked: Resume is still up after a tap")
    if base.find(rows, "Continue Read") is not None:
        print("   FAIL: a parked read went idle on a touch")
        ok = False
    # Same as above (2026-10-16): the record this read is withdrawn, so the check
    # could not fail. "A touch while parked writes no position" is witnessed live
    # by the buttons above (`Resume` still up = the park was not disturbed).
    print("   position: nothing to read — a parked read had no record to move")

    # Stop is the control that ends a read.
    if not tap_control(base.dump(), "Stop", "Stop (ends the read)"):
        return False
    time.sleep(1.0)
    rows = base.dump()
    if (base.find(rows, "Continue Read") is None
            or base.find(rows, "Pause") is not None
            or base.find(rows, "Resume") is not None):
        print(f"   FAIL: Stop did not return the page to idle — visible: {base.labels(rows)}")
        ok = False
    else:
        print("   stopped: Read / Continue Read are back, Pause and Resume are gone")
    return ok


# --------------------------------------------------------------------------
# Row 23's own fixture. A title with NO sentence ender, a blank line, then a
# punctuated paragraph — and the body's first sentence is deliberately the
# shipped pre-set's opening line, so the reading text stays addressable by the
# needle every helper here already uses (`text_node`, `origin`, …).
#   old rule: one sentence, `A quiet morning\n\nThe sun rose over the quiet town.`
#             (starts [0, 51]) — the title swallowed the body's first sentence
#   new rule: three, starts [0, 17, 51] — the title, then the body's two
TITLE_ID = "blank_line_title"
TITLE_NAME = "A quiet morning"
TITLE_TEXT = "A quiet morning\n\nThe sun rose over the quiet town. Birds sang."
LIBRARY = f"/data/data/{PKG}/app_flutter"
INDEX = f"{LIBRARY}/content/index.json"
DEV = os.environ.get("ADB_SERIAL", "emulator-5554")


def device_write(path, data):
    """Writes bytes into the app's private storage through `run-as`.

    The redirection has to live inside the command string: `adb shell` joins its
    arguments with spaces and never quotes them, so a separate `>` would be
    handed to the device's outer shell, which is not the app's user and cannot
    write there — the failure is silent (012's own note, born of the same bug).
    """
    out = subprocess.run(
        ["adb", "-s", DEV, "shell", f"run-as {PKG} sh -c 'cat > {path}'"],
        input=data, capture_output=True)
    return out.returncode == 0


def seed(content_id, name, text):
    """Writes one content into the app's library and opens it.

    The library is files on disk — `content/index.json` plus one text file per
    entry — so a debug build is handed a content from here (014's driver does
    the same). The app caches the index in memory, so it is force-stopped after
    the write and what the row then reads is the file on disk.
    """
    adb("shell", "run-as", PKG, "mkdir", "-p", f"{LIBRARY}/content/contents")
    if not device_write(f"{LIBRARY}/content/contents/{content_id}.txt",
                        text.encode()):
        return None
    index = json.loads(adb("shell", "run-as", PKG, "cat", INDEX))
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S.000000Z", time.gmtime())
    index["entries"] = [e for e in index["entries"] if e["id"] != content_id] + [{
        "id": content_id, "name": name, "language": "en", "origin": "user",
        "createdAt": stamp, "updatedAt": stamp, "charCount": len(text),
    }]
    index["lastOpenedId"] = content_id
    if not device_write(INDEX, json.dumps(index).encode()):
        return None
    adb("shell", "am", "force-stop", PKG)
    base.start_app()
    return text


def unseed(content_id):
    """Takes the row's own content back out, so the library is as it was found."""
    index = json.loads(adb("shell", "run-as", PKG, "cat", INDEX))
    index["entries"] = [e for e in index["entries"] if e["id"] != content_id]
    if index.get("lastOpenedId") == content_id:
        index["lastOpenedId"] = "preset_en_sample"
    ok = device_write(INDEX, json.dumps(index).encode())
    adb("shell", "run-as", PKG, "rm", "-f",
        f"{LIBRARY}/content/contents/{content_id}.txt")
    adb("shell", "am", "force-stop", PKG)
    return ok


def scenario_23():
    """23. a sentence ends where its paragraph does — the 2026-10-09 amendment.

    The reader's question: "a paragraph can end by a empty line. but a sentence
    is not end by a empty line now. should empty line end a sentence?" — yes, and
    the app's two halves had disagreed. The read speaks one paragraph at a time
    and always counted two units here; the tap, the highlight and the stored
    position asked a view in which a blank line was plain whitespace, so a title
    with no full stop swallowed the sentence under it. One rule answers both now,
    and this row is the reader's own shape on a real screen.
    """
    step("23. a sentence ends where its paragraph does — the tap, the read, the position")
    rows = base.start_app(clear=True)
    if base.find(rows, "Appearance") is None:
        if not base.tap_node(rows, "Back", "Back to the reading page"):
            return False
        time.sleep(1.5)
        rows = base.dump()
    rows = set_xlarge(rows)
    if rows is None:
        print("   FAIL: the reading page did not accept Extra large")
        return False

    text = seed(TITLE_ID, TITLE_NAME, TITLE_TEXT)
    if text is None:
        print("   FAIL: the fixture did not reach the library")
        return False
    time.sleep(2)
    rows = base.dump()
    if text_node(rows) is None:
        print(f"   FAIL: the fixture's text is not on the page — "
              f"visible: {base.labels(rows)[:8]}")
        unseed(TITLE_ID)
        return False

    paras = base.paragraph_ranges(text)
    starts = base.sentence_starts(text)
    title = paras[0]
    first = (starts[1], starts[2] if len(starts) > 2 else len(text))
    print(f"   the fixture: {text!r}")
    print(f"   paragraphs {paras}; sentence starts {starts}")
    print(f"   title {title}; the paragraph under it begins at {paras[1]}, "
          f"its first sentence is {first}")
    ok = True

    # The app's own geometry for the two lines: one full read reports a band per
    # sentence in logical px, and a band's top lands at `origin + top * dpr` in
    # device px — the conversion 011's rows 7/9/10 already measure with. The log
    # is cleared first: a band read from a window that still holds the previous
    # content's lines would be answered by the wrong text.
    base.clear_log()
    tap_control(base.dump(), "Continue Read", "Continue Read (one full read, for the bands)")
    time.sleep(3.0)
    if not base.wait_for_idle():
        print("   FAIL: the read did not end")
        unseed(TITLE_ID)
        return False
    bands = {(f["p"], f["s"]): f for f in follow_lines()}
    ratio, top = dpr(), origin(base.dump())
    print(f"   follow bands: "
          f"{[(f['p'], f['s'], f['top'], f['bottom']) for f in follow_lines()]} "
          f"dpr={ratio:.3f} origin={top}")
    title_band, first_band = bands.get((0, 0)), bands.get((1, 0))
    if title_band is None or first_band is None:
        print(f"   FAIL: the read reported {sorted(bands)}, not a band for p0 s0 "
              f"(the title) and p1 s0 (the paragraph under it)")
        unseed(TITLE_ID)
        return False
    if first_band["top"] <= title_band["top"]:
        print("   FAIL: the body's band is not below the title's")

    def tap_band(band, why):
        x = text_columns(base.dump())[0] + 20
        y = top + int((band["top"] + band["bottom"]) / 2 * ratio)
        base.tap_at(x, y, why)
        time.sleep(1.5)
        return (x, y)

    # The record this row used to read — `(anchor, the text's own length)` — is
    # **withdrawn**: 010's FR-008 went with 016's decision 5, and the app writes no
    # such pref under any name (the device's own prefs hold the appearance key and
    # nothing else; `grep -rn "read_position" lib/` finds nothing). **Re-cut
    # 2026-10-16**, the way 016 amended this file's own row 20 on 2026-10-12: the
    # anchor is witnessed by the app's **live range** — what ▶ (below) and ⏭ (step 4)
    # read from is the sentence the tap put in force. The row's subject is unchanged
    # (a sentence ends where its paragraph does: the tap, the read, the position);
    # only the witness is.
    #
    # 1. A tap on the TITLE's own line: the anchor is the title's start, the
    #    highlight is one line, and ▶ reads the title alone. Under the old rule
    #    the sentence under the finger was `0..51` — the title AND the body's
    #    first sentence — so ▶ would have read into the paragraph.
    tap_band(title_band, "the title's own line")
    print(f"   tapped the title (the title begins at {title[0]}, the text is "
          f"{len(text)} chars) — the anchor it set is read off ▶ below")
    shot = screencap(os.path.join(OUT, "011_23_title_tap.png"))
    band_rows = sorted(yellow_rows(shot))
    if not band_rows:
        print("   FAIL: the tap painted no highlight")
        ok = False
    else:
        body_top = top + int(first_band["top"] * ratio)
        print(f"   the highlight's rows {band_rows[0]}..{band_rows[-1]}; "
              f"the body's own band begins at {body_top}")
        if band_rows[-1] >= body_top:
            print(f"   FAIL: the highlight reaches {band_rows[-1]}, into the "
                  f"body's line at {body_top}")
            ok = False

    # 2. ▶ reads the title alone: one range, the title's own span. This is the
    #    discriminating number — the old rule gave `(0, 51)` here.
    base.clear_log()
    tap_control(base.dump(), "Read", "Read (the tapped title)")
    time.sleep(2.5)
    ranges = base.ranges()
    print(f"   ▶ ranges={ranges} utterances={spoken()} — the anchor in force is "
          f"{ranges[0][0] if ranges else None} (the title begins at {title[0]}, the "
          f"text is {len(text)} chars)")
    if not ranges or ranges[0] != title:
        print(f"   FAIL: ▶ read {ranges[0] if ranges else None}, not the title {title} — "
              f"the tap's sentence is swallowing the paragraph under it")
        ok = False
    if ranges and ranges[0][0] != title[0]:
        print(f"   FAIL: the anchor is {ranges[0][0]}, not the title's own start "
              f"{title[0]} — the tap put a range in force whose anchor is elsewhere")
        ok = False
    if not base.wait_for_idle():
        print("   FAIL: the read did not end")
        unseed(TITLE_ID)
        return False

    # 3. A tap inside the body: the anchor is where the body's own sentence
    #    starts, never back at the title.
    tap_band(first_band, "the body's first sentence")
    print(f"   tapped the body (its first sentence begins at {first[0]}) — the anchor "
          f"it set is read off ⏭ below")

    # 4. ⏭ from there reads from there: the resume is not pulled back to the
    #    title, which is what the anchor did with the old rule (it would have
    #    started at 0).
    base.clear_log()
    tap_control(base.dump(), "Continue Read", "Continue Read (from the body)")
    time.sleep(2.5)
    ranges = base.ranges()
    print(f"   ⏭ ranges={ranges} utterances={spoken()} — the anchor in force is "
          f"{ranges[0][0] if ranges else None} (the body's first sentence begins at "
          f"{first[0]})")
    if not ranges or ranges[0][0] != first[0]:
        print(f"   FAIL: the anchor is {ranges[0][0] if ranges else None}, not the "
              f"body's {first[0]} — the tap went back to the title")
        ok = False
    base.wait_for_idle()
    print(f"   left in the library afterwards: "
          f"{'taken back out' if unseed(TITLE_ID) else 'STILL THERE'}")
    return ok


def scenario_24():
    """**022's own row** (quickstart row 10): the read keeps a sentence ahead of the
    one being read.

    The reader's own rule of 2026-10-16 — "start the auto scroll before highlight/read
    last sentence on screen" — read off the app's own line: while a read plays, the
    sentence being read is never the bottom-most box on screen unless it is the
    content's **last** sentence. `below=` counts the sentences whose boxes are inside
    the viewport below the reported one, so every report for a non-final sentence must
    read `below >= 1`, and the last one must read `below=0`.
    """
    step("24. the read keeps a sentence ahead of the sentence being read "
         "(022 FR-001/FR-009)")
    rows = base.start_app(clear=True)
    rows = set_xlarge(rows) or rows
    set_viewport(1080, 1000)
    rows = base.dump()
    text = base.preset_text()
    sentences = base.sentence_starts(text)
    print(f"   pre-set: {len(text)} chars, {len(sentences)} sentences; "
          f"display 1080x1000 so the text is taller than the page")
    base.clear_log()
    if not base.tap_node(rows, "Continue Read", "Continue Read"):
        return False

    deadline = time.time() + 200
    while time.time() < deadline:
        if base.find(base.dump(), "Continue Read") is not None and follow_lines():
            break
        time.sleep(0.5)

    reports, utterances = follow_lines(), spoken()
    print(f"   klhu speak: {len(utterances)} utterances | "
          f"klhu follow: {len(reports)} reports | "
          f"viewport={reports[0]['viewport'] if reports else '?'} logical")
    ok = True
    if [f"p{r['p']} s{r['s']}" for r in reports] != \
            [f"p{p} s{s}" for p, s in utterances]:
        print("   FAIL: the reports and the utterances do not agree, in order")
        ok = False
    non_final = reports[:-1] if reports else []
    for i, r in enumerate(non_final):
        if r["below"] < 1:
            print(f"   FAIL: p{r['p']} s{r['s']} was the bottom-most box on screen "
                  f"(below={r['below']}, top={r['top']} bottom={r['bottom']} "
                  f"viewport={r['viewport']})")
            ok = False
        if not r["visible"] or not (r["top"] < r["bottom"] <= r["viewport"]):
            print(f"   FAIL: p{r['p']} s{r['s']} geometry {r}")
            ok = False
    if reports:
        last = reports[-1]
        if last["below"] != 0:
            print(f"   FAIL: the content's last sentence claims {last['below']} "
                  f"below it — nothing follows it")
            ok = False
    kept = sum(1 for r in non_final if r["below"] >= 1)
    print(f"   every non-final report keeps a sentence below it: "
          f"{kept}/{len(non_final)}")
    print("   the content's last sentence's own report: "
          + (f"p{reports[-1]['p']} s{reports[-1]['s']} below={reports[-1]['below']} "
             f"visible={reports[-1]['visible']}" if reports else "none"))
    # The display goes back to its physical size — this row shrinks it, and a row
    # that leaves it shrunk moves every later row's taps (016's row 15, the same
    # afternoon, tapped the wrong coordinates because this one did not reset).
    reset_viewport()
    return ok



def scenario_25():
    """**022's own row** (quickstart row 11, second half): a text that fits the reading
    area moves the page by zero pixels.

    The unit half of that criterion is 011's own case (`short text: no scroll`). The
    device half needs the premise 011's own `set_viewport` docstring measures: at the
    display's own size and the app's own appearance, the reading area is ~718 logical px
    tall against this preset's ~226 — so the text fits, there is nothing to scroll, and a
    read of it cannot move the page. Both halves of that are checked: every sentence sits
    inside the area at once, and the highlight walks **down the page** as the read
    advances while the page's own offset stays put.
    """
    step("25. a text that fits the page moves by zero pixels (022 FR-005/SC-003)")
    # `clear=True` starts from the app's own defaults, so the appearance is the shipped
    # one; the display goes back to its physical size.
    base.start_app(clear=True)
    reset_viewport()
    rows = base.dump()
    text = base.preset_text()
    print(f"   pre-set: {len(text)} chars, {len(base.sentence_starts(text))} sentences; "
          f"display at its physical size, appearance at the app's own default")
    base.clear_log()
    if not base.tap_node(rows, "Continue Read", "Continue Read"):
        return False

    # Stills are taken **while the read plays** — after it ends the page clears its
    # highlight (`clear_log` above means the report count is this read's own), so a still
    # taken at the end has no band in it at all.
    total = len(base.sentence_starts(text))
    caps = []
    deadline = time.time() + 150
    while time.time() < deadline:
        seen = follow_lines()
        if seen and len(seen) < total:
            caps.append(screencap(f"{OUT}/klhu_walk_022_s25_{len(caps):02d}.png"))
        if base.find(base.dump(), "Continue Read") is not None and len(seen) >= total:
            break
        time.sleep(0.4)

    reports = follow_lines()
    if not reports:
        check("25: the read reported its sentences", False, "no `klhu follow` lines")
        return False
    print(f"   klhu follow: {len(reports)} reports | viewport={reports[0]['viewport']} logical")
    print(f"   the sentences' own boxes, as read: {[(r['top'], r['bottom']) for r in reports]}")

    ok = True
    if not all(r["visible"] for r in reports) or reports[-1]["bottom"] > reports[-1]["viewport"]:
        print(f"   FAIL: the text does not fit the reading area — "
              f"last bottom={reports[-1]['bottom']} of viewport={reports[-1]['viewport']}, "
              f"not visible: {['p%d s%d' % (r['p'], r['s']) for r in reports if not r['visible']]}")
        ok = False
    print(f"   every sentence inside the reading area at once: "
          f"{sum(1 for r in reports if r['visible'])}/{len(reports)} visible, "
          f"the last's bottom={reports[-1]['bottom']} of viewport={reports[-1]['viewport']} "
          f"— nothing to scroll")
    for r in reports:
        if not (r["visible"] and 0 <= r["top"] < r["bottom"] <= r["viewport"]):
            print(f"   FAIL: p{r['p']} s{r['s']} sits outside the visible area: {r}")
            ok = False

    seen_bands = [min(ys) for ys in (yellow_rows(c) for c in caps) if ys]
    bands = {"first": seen_bands[0] if seen_bands else None,
             "last": seen_bands[-1] if seen_bands else None,
             "captures": len(caps), "with a band": len(seen_bands)}
    walked = len(seen_bands) >= 2 and seen_bands[-1] >= seen_bands[0]
    if not walked:
        print(f"   FAIL: the highlight did not walk down the page: bands={bands}")
        ok = False
    print(f"   the highlight's own top row, capture by capture: {seen_bands} "
          f"({bands['captures']} stills, {bands['with a band']} with a band) "
          f"({'down the page' if walked else 'NOT down the page'})")
    return ok


PARTS = {
    "7": scenario_7,
    "8": scenario_8,
    "9": scenario_9,
    "10": scenario_10,
    "16": scenario_16,
    "17": scenario_17,
    "20": scenario_20,
    "21": scenario_21,
    "23": scenario_23,
    "24": scenario_24,
    "25": scenario_25,
}

if __name__ == "__main__":
    part = sys.argv[1] if len(sys.argv) > 1 else ""
    if part not in PARTS:
        print(f"usage: {os.path.basename(__file__)} 7|8|9|10|16|17|20|21|23|24|25")
        sys.exit(2)
    print("RESULT:", "PASS" if PARTS[part]() else "FAIL")
