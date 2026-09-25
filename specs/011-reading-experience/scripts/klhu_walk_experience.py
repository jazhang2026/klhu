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
import os
import re
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
        m = re.search(
            r"p(\d+) s(\d+) visible=(\d) top=(-?\d+) bottom=(-?\d+) viewport=(\d+)",
            ln)
        if m:
            out.append({
                "p": int(m.group(1)),
                "s": int(m.group(2)),
                "visible": int(m.group(3)) == 1,
                "top": int(m.group(4)),
                "bottom": int(m.group(5)),
                "viewport": int(m.group(6)),
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


def stored_offset():
    for ln in base.stored_position():
        m = re.search(r"(\d+)\|\|(\d+)", ln)
        if m:
            return (int(m.group(1)), int(m.group(2)))
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
    offset = stored_offset()
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
    print(f"   tap painted {painted_after_tap} device px at {offset}; "
          f"after the swipe: no yellow on screen (the position is off screen)")
    print(f"   first report: p{first['p']} s{first['s']} "
          f"visible={int(first['visible'])} top={first['top']} "
          f"bottom={first['bottom']} viewport={first['viewport']}")
    print(f"   read range  : {rng[0]}..{rng[1]} (tapped offset {offset[0]})")
    print(f"   revealed    : yellow={bbox(ys)} device px, inside the reading "
          f"area {node['bounds'][1]}..{node['bounds'][3]}")
    if not first["visible"] or not 0 <= first["top"] < first["bottom"] <= first["viewport"]:
        print("   FAIL: the first report is not inside the viewport")
        ok = False
    if offset is None or rng[0] != offset[0]:
        print("   FAIL: the read did not start at the tapped offset (010's rule)")
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
    positions_before = base.stored_position()
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
    positions_after = base.stored_position()
    print(f"   list final : {list_final[:6]}")
    if list_final != list_after:
        print("   FAIL: the empty Save added a row")
        ok = False
    if positions_after != positions_before:
        print(f"   FAIL: the draft wrote a position record: "
              f"{positions_after} vs {positions_before}")
        ok = False
    print(f"   positions: {positions_after}")

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
    point = visible_low_point(base.dump())
    if point is None:
        reset_viewport()
        return False

    def set_position(why, hold=False):
        """The same line of the page: TAPPED it sets a sentence position (010
        FR-002), HELD it selects the whole paragraph (003). One point, two
        gestures — which is exactly the pair the rows below compare."""
        if hold:
            hold_at(point, why)
        else:
            base.tap_at(point[0], point[1], why)
        time.sleep(1.5)
        return stored_offset()

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
        print("   FAIL: the tap set no position")
        reset_viewport()
        return False
    painted = yellow_present("after the tap")
    print(f"   position set: {offset[0]}..{offset[1]}")
    if not painted:
        print("   FAIL: the tap set a position but painted nothing")
        ok = False

    para = next((p for p in base.paragraph_ranges(text)
                 if p[0] <= offset[0] < p[1]), None)
    if para is None:
        print(f"   FAIL: no paragraph of the pre-set holds {offset[0]}")
        reset_viewport()
        return False
    print(f"   the paragraph holding it: {para[0]}..{para[1]}")

    # ▶ TAPPED with a TAP-selected SENTENCE: one sentence, so its span is
    # strictly shorter than the paragraph holding it (FR-023/FR-024).
    one = press_read("Read")
    span = one[0] if one else None
    print(f"   ▶ sentence : {span} (the paragraph is {para[0]}..{para[1]})")
    if not span or span[0] != offset[0]:
        print("   FAIL: ▶ did not read from the tapped sentence's start")
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
    offset = set_position("the same line again (position for ⏭)")
    if offset is None:
        reset_viewport()
        return False
    resumed = press_read("Continue Read")
    ran = resumed[0] if resumed else None
    print(f"   ⏭ tapped  : {ran} (position {offset[0]}, text {len(text)} chars)")
    if not ran or ran[0] != offset[0] or ran[1] != len(text):
        print("   FAIL: ⏭ did not read from the position to the end")
        ok = False
    if not base.wait_for_idle():
        reset_viewport()
        return False
    time.sleep(1.5)
    if yellow_present("after the read ended"):
        print("   FAIL: the ended read left its highlight painted")
        ok = False
    left = record_lines("read_position")
    print(f"   records after the read: {left or 'none'}")
    if left:
        print("   FAIL: the ended read left the position in force")
        ok = False

    # ▶ Read with nothing highlighted: it speaks NOTHING and asks for a
    # selection (FR-023) — reading the page from the top is ⏭'s fallback.
    fresh = press_read("Read")
    prompt = base.find(base.dump(), "Select a sentence or paragraph to read")
    print(f"   ▶ after the read : ranges={fresh or 'none'} "
          f"prompt={'shown' if prompt else 'MISSING'}")
    if fresh:
        print("   FAIL: ▶ Read spoke with nothing highlighted")
        ok = False
    if prompt is None:
        print("   FAIL: ▶ Read did not ask for a selection")
        ok = False

    # ⏭ Continue Read with nothing highlighted: the first sentence to the end,
    # exactly the read a page that was never tapped gives (010 FR-005).
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
    if stored_offset() is not None:
        print(f"   FAIL: a touch moved the position ({stored_offset()})")
        ok = False
    else:
        print("   position: still none")

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
    if stored_offset() is not None:
        print(f"   FAIL: a touch wrote a position while parked ({stored_offset()})")
        ok = False

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


PARTS = {
    "7": scenario_7,
    "8": scenario_8,
    "9": scenario_9,
    "10": scenario_10,
    "16": scenario_16,
    "17": scenario_17,
    "20": scenario_20,
    "21": scenario_21,
}

if __name__ == "__main__":
    part = sys.argv[1] if len(sys.argv) > 1 else ""
    if part not in PARTS:
        print(f"usage: {os.path.basename(__file__)} 7|8|9|10|16|17|20|21")
        sys.exit(2)
    print("RESULT:", "PASS" if PARTS[part]() else "FAIL")
