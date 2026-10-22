#!/usr/bin/env python3
"""klhu device walk — 024 quickstart rows 10-14.

Row 10: the page shows nothing of the tag, and it paints the deleted-line twin
        (FR-004, SC-002, SC-006).
Row 11: the read runs through a boundary with no pause and no silence — the
        same utterances, in the same order, as the twin (FR-005, SC-003).
Row 12: EDIT, Format, one Undo — blank lines only, and the input back after one
        Undo (FR-006, SC-004).
Row 13: five pictures, the option's label, the thumbnails' counts after it
        (FR-008, FR-009, FR-011, FR-012, SC-005).
Row 14: the render's own slot lines, and no frame carrying a tag (FR-004,
        FR-005, SC-008).

The mechanics are the tree's own modules, imported rather than re-written:
020's fixture, pictures, prompt, pass and render polling (`klhu_walk_assignment`
through 021's `klhu_walk_pass`), 014's `seed`/editor reads/Format press, and
016's read helpers (`press_read`, `wait_for_read_end`, `logged_text`).

Usage:  /usr/bin/python3 -u klhu_walk_scene.py 10
        ADB_SERIAL=emulator-5554 /usr/bin/python3 -u klhu_walk_scene.py 10
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.
"""
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "021-picture-pass", "scripts"))
sys.path.insert(0, os.path.join(REPO, "specs", "016-sentence-reading", "scripts"))
sys.path.insert(0, os.path.join(REPO, "specs", "014-dialogue-reading", "scripts"))

import klhu_walk_pass as pass021  # noqa: E402
import klhu_walk_step as step016  # noqa: E402
import klhu_walk_dialogue as dialogue014  # noqa: E402

base = pass021.base
adb = base.adb
dump = base.dump
fresh_dump = base.fresh_dump
dump_until = base.dump_until
check = base.check
labels = base.labels
find = base.find
tap = base.tap
on_screen = base.on_screen
screencap = base.screencap
wait_for = getattr(base, "wait_for", None) or step016.wait_for
fresh_prefs = dialogue014.fresh_prefs
seed = dialogue014.seed
unseed_fixture = dialogue014.unseed_fixture
unxml = dialogue014.unxml
press = dialogue014.press
press_read = step016.press_read
wait_for_read_end = step016.wait_for_read_end
logged_text = step016.logged_text
ranges_since = step016.ranges_since
speak_lines = step016.speak_lines
clear_logcat = base.clear_logcat
logcat = base.logcat
push_pictures = base.push_pictures
open_video_dialog = base.open_video_dialog
open_pass = base.open_pass
start_render = base.start_render
video = base.video
OUT = base.OUT
PKG = base.PKG

# ---------------------------------------------------------------------------
# The fixture — quickstart's own six lines, written beside this driver so a
# reader can diff it against the spec's block.
FIXTURE_PATH = os.path.join(HERE, "klhu_scene_fixture.txt")
CONTENT_ID = "scene_024_fixture"
CONTENT_NAME = "场景样本"

TWIN_ID = "scene_024_twin"
TWIN_NAME = "场景样本（删行）"

TAG_RE_LINE = re.compile(r"^[ \t]*\[(scene|escena|场景|場景)\]", re.IGNORECASE)


def fixture_text():
    with open(FIXTURE_PATH, encoding="utf-8") as handle:
        return handle.read()


def tag_spans(text):
    """Every tag line's span — the rule `lib/scene_tag.dart` implements, line by
    line: `[lineStart, lineEnd + 1)`, the line's break included."""
    spans, at = [], 0
    for line in text.splitlines(keepends=True):
        stripped = line.rstrip("\n")
        if TAG_RE_LINE.match(stripped):
            end = at + len(stripped.rstrip("\r\n"))
            spans.append((at, min(end + 1, len(text))))
        at += len(line)
    return spans


def deleted(text):
    """The content with every tag line deleted — the twin every surface is
    measured against (FR-004, FR-005)."""
    out, cursor = [], 0
    for start, end in tag_spans(text):
        out.append(text[cursor:start])
        cursor = end
    out.append(text[cursor:])
    return "".join(out)


def masked(text):
    """The same-length mask the read is cut from (data-model §3) — used here only
    to say what the app's own sentences should be."""
    chars = list(text)
    for start, end in tag_spans(text):
        for i in range(start, end):
            chars[i] = " "
    return "".join(chars)


def app_sentences(text):
    """The sentences the app speaks, by the app's own rule: blank lines cut
    paragraphs, and `. ! ? ; 。！？；` (plus ASCII `...`) end a sentence."""
    import re as _re
    out = []
    for para in _re.split(r"\n[ \t]*\n+", text):
        buf, i = "", 0
        while i < len(para):
            ch = para[i]
            buf += ch
            if ch in ".!?;。！？；" or para.startswith("...", i) or \
                    para.startswith("……", i):
                out.append(buf.strip())
                buf = ""
            i += 1
        if buf.strip():
            out.append(buf.strip())
    return [s for s in out if s]


# ---------------------------------------------------------------------------
def screenshot(name):
    """A still of the page, kept for a reader to look at (012's own capture)."""
    path = os.path.join(OUT, f"scene_{name}.png")
    made = base.screencap(path)
    print(f"   screenshot → {path}")
    return made


def ink_profile(path, top=420, bottom=2200):
    """Which scanlines of the page's text area carry ink — 023's own band read,
    applied to the page instead of a frame.

    Two pages painting the same text ink the same scanlines; a tag line left
    painted would add rows of its own, and a gap where a tag stood would show as
    a run of blank scanlines inside the text block that no line spacing explains.
    """
    from PIL import Image
    image = Image.open(path).convert("L")
    width, height = image.size
    pixels = image.load()
    inked = []
    for y in range(top, min(bottom, height)):
        dark = 0
        for x in range(40, width - 40, 3):
            if pixels[x, y] < 120:
                dark += 1
        inked.append(dark > 0)
    first = next((i for i, row in enumerate(inked) if row), None)
    last = next((i for i, row in enumerate(reversed(inked)) if row), None)
    if first is None or last is None:
        return inked, 0, 0
    last = len(inked) - 1 - last
    block = inked[first:last + 1]
    widest, run = 0, 0
    for row in block:
        run = 0 if row else run + 1
        widest = max(widest, run)
    return inked, sum(1 for row in block if row), widest


def painted(rows, needle):
    """The node the page paints its content in — the one label that carries
    [needle], which is the reading page's own text block (016's `text_block`,
    keyed off this row's own fixture rather than another row's)."""
    for row in rows:
        label = row["desc"] or row["text"] or ""
        if needle in label:
            return label
    return None


def wait_painted(needle, seconds=12):
    """The page, once its content is painted: a dumped page that carries only the
    toolbar is a page still landing (the first frame of a debug build)."""
    started = time.time()
    while time.time() - started < seconds:
        rows = dump()
        text = painted(rows, needle)
        if text is not None:
            return rows, text
        time.sleep(0.7)
    return dump(), None


def open_content(cid=CONTENT_ID, name=CONTENT_NAME, text=None):
    """Seeds one content and leaves the app on its reading page, its content
    painted — the state every row below reads."""
    fresh_prefs()
    body = text if text is not None else fixture_text()
    if seed(cid, name, body) is None:
        return None, None
    needle = body.strip().splitlines()[0].strip()
    return wait_painted(needle)


def row_10():
    base.step("row 10 — the page shows nothing of the tag, and paints the twin")
    text = fixture_text()
    twin = deleted(text)
    check("10: the fixture holds three tag lines", len(tag_spans(text)) == 3,
          f"spans: {tag_spans(text)}")

    rows, fixture_painted = open_content()
    if fixture_painted is None:
        check("10: the fixture reached the page", False,
              f"the page's nodes: {labels(rows)[:10]}")
        return
    cap = screenshot("row10_fixture")
    if cap is None:
        check("10: the page could be captured", False, "screencap returned no PNG")
        return
    for gone in ("[场景]", "[scene]", "青石观蚁", "1：", "2："):
        check(f"10: the page holds no {gone!r}", gone not in fixture_painted,
              f"the painted block: {fixture_painted!r}")

    rows, twin_painted = open_content(TWIN_ID, TWIN_NAME, twin)
    if twin_painted is None:
        check("10: the twin reached the page", False,
              f"the page's nodes: {labels(rows)[:10]}")
        return
    twin_cap = screenshot("row10_twin")
    if twin_cap is None:
        check("10: the twin could be captured", False, "screencap returned no PNG")
        return

    check("10: the page paints the deleted-line twin, byte for byte",
          fixture_painted == twin,
          f"the page reads {len(fixture_painted)} chars, the twin "
          f"{len(twin)}; equal: {fixture_painted == twin}")
    check("10: the twin's page paints the same block",
          twin_painted == twin, f"the twin's page: {twin_painted!r}")

    fixture_profile, fixture_inked, fixture_gap = ink_profile(cap)
    twin_profile, twin_inked, twin_gap = ink_profile(twin_cap)
    differing = sum(1 for a, b in zip(fixture_profile, twin_profile) if a != b)
    print(f"   the fixture's page: {fixture_inked} inked scanlines in its text "
          f"block, widest line gap {fixture_gap}px")
    print(f"   the twin's page:    {twin_inked} inked scanlines, widest line gap "
          f"{twin_gap}px")
    check("10: the two pages ink the same scanlines (within 2 rows)",
          differing <= 2, f"{differing} scanline(s) differ")
    check("10: no gap of page background where a tag stood",
          fixture_gap <= twin_gap + 2,
          f"the widest line gap is {fixture_gap}px on the fixture and "
          f"{twin_gap}px on the twin (a line's own spacing is "
          f"{twin_gap}px)")
    unseed_fixture(TWIN_ID)


def speak_through(max_presses=12, seconds=30):
    """The whole text, read: ▶ pressed once per step, from the first sentence to
    the last, collecting the app's own `klhu speak` lines.

    One press reads ONE step (016's own model — the button advances the
    highlight), so a whole text is a sequence of presses. The end is the press
    that starts over: at the text's end nothing is in force and ▶ takes the first
    step again, which the app's own `klhu read range` line shows as a start that
    does not advance.
    """
    spoken, last_start = [], -1
    for _ in range(max_presses):
        clear_logcat()
        if not press_read():
            break
        wait_for_read_end(seconds=seconds)
        log = logcat()
        lines = [line["text"] for line in step016.speak_lines(log)]
        ranges = [(int(a), int(b)) for a, b in
                  re.findall(r"klhu read range: (\d+)\.\.(\d+)", log)]
        if not lines:
            break
        start = ranges[0][0] if ranges else -1
        if start <= last_start:
            print(f"   the read is at its end: ▶ started over at {start}")
            break
        print(f"   press {len(spoken) + len(lines)}: range(s) {ranges}, "
              f"spoken {lines}")
        spoken += lines
        last_start = start
    return spoken


def row_11():
    base.step("row 11 — the read runs through a boundary, silent on the tag")
    text = fixture_text()
    twin = deleted(text)
    expected = app_sentences(twin)

    rows, page = open_content()
    if page is None:
        check("11: the fixture reached the page", False, f"{labels(rows)[:10]}")
        return
    spoken = speak_through()
    print("   the fixture's own utterances:")
    for line in spoken:
        print(f"     {line}")
    rows, page = open_content(TWIN_ID, TWIN_NAME, twin)
    if page is None:
        check("11: the twin reached the page", False, f"{labels(rows)[:10]}")
        return
    twin_spoken = speak_through()
    print("   the twin's own utterances:")
    for line in twin_spoken:
        print(f"     {line}")

    check("11: both reads speak the same number of utterances",
          len(spoken) == len(twin_spoken),
          f"{len(spoken)} on the fixture, {len(twin_spoken)} on the twin")
    check("11: the same texts in the same order",
          spoken == twin_spoken,
          f"first difference: "
          f"{next((i for i, (a, b) in enumerate(zip(spoken, twin_spoken)) if a != b), None)}")
    check("11: no utterance is blank or carries a tag",
          all(line and "[" not in line for line in spoken),
          f"blank or tagged: {[l for l in spoken if not l or '[' in l]}")
    check("11: the read speaks the twin's own sentences",
          [logged_text(s) for s in expected] == [l for l in spoken],
          f"the twin's sentences, by the app's own rule: "
          f"{[logged_text(s) for s in expected]}")
    unseed_fixture(TWIN_ID)


def field_text(rows=None):
    """The editor's own text, off the page — 014's own read, keyed off THIS row's
    fixture instead of 014's: in edit mode a Flutter field's whole contents are
    one node's label, with the dump's own escapes to undo."""
    rows = dump() if rows is None else rows
    hits = [unxml(r["desc"] or r["text"] or "") for r in rows
            if "[场景]" in (r["desc"] or r["text"] or "")]
    return max(hits, key=len) if hits else None


def wait_field_ready(text, tries=12, pause=0.5):
    """The editor, once its field holds [text] **and** its Format button is
    enabled — the state the press is made in. A debug build compiles the editor's
    first frame on the UI thread, and pressing into that frame drops the click
    (014's own finding)."""
    for _ in range(tries):
        rows = dump()
        node = next((r for r in rows
                     if (r["desc"] or r["text"]) in dialogue014.L["format"]), None)
        if node is not None and node["enabled"] and field_text(rows) == text:
            return rows
        time.sleep(pause)
    return None


ROW12_ID = "scene_024_format"
ROW12_NAME = "排版样本"
ROW12_TEXT = "他推门进来。\n[场景] 1：青石观蚁\n屋里很暗。"


def row_12():
    base.step("row 12 — one press, one Undo, blank lines only")
    fresh_prefs()
    if seed(ROW12_ID, ROW12_NAME, ROW12_TEXT) is None:
        check("12: the row's own content reached the device", False, "seed failed")
        return
    time.sleep(1.2)
    if not press("edit", "the editor entry"):
        check("12: the editor opened", False, f"visible: {labels(dump())[:12]}")
        return
    if wait_field_ready(ROW12_TEXT) is None:
        check("12: the field was ready before the press", False,
              f"visible: {labels(dump())[:14]}")
        return
    before = field_text()
    check("12: the editor shows the row's text, byte for byte", before == ROW12_TEXT,
          f"the field reads {before!r}")

    if not press("format", "the Format button"):
        check("12: the Format button is on the toolbar", False,
              f"visible: {labels(dump())[:14]}")
        return
    after = field_text()
    check("12: the tag line stands alone after the press",
          after is not None and "\n\n[场景] 1：青石观蚁\n" in after,
          f"the field reads {after!r}")
    check("12: no character changed — the diff is one blank line",
          (after or "").replace("\n", "") == (before or "").replace("\n", ""),
          f"{len(before or '')} chars → {len(after or '')} chars, "
          f"{len(after or '') - len(before or '')} added")

    press("format", "the Format button again")
    again = field_text()
    check("12: a second press changes nothing — the text is already formatted",
          again == after, f"{len(again or '')} chars")

    press("undo", "Undo")
    undone = field_text()
    check("12: one Undo puts the input back, byte for byte", undone == before,
          f"the field reads {undone!r}")
    unseed_fixture(ROW12_ID)


PICTURES_5 = [
    ("w024_white.png", (255, 255, 255)),
    ("w024_black.png", (0, 0, 0)),
    ("w024_red.png", (220, 30, 30)),
    ("w024_blue.png", (30, 60, 200)),
    ("w024_green.png", (30, 160, 70)),
]


def strip_names(rows, names):
    """The strip's pictures in the order the page draws them — the cells' own
    order on screen, read off their x positions (020's `chip_order` shape, with
    this row's own five names)."""
    found = []
    for row in rows:
        label = row["desc"] or row["text"] or ""
        for name in names:
            if label.startswith(name + "\n") and name not in [n for n, _ in found]:
                found.append((name, row["x"]))
    found.sort(key=lambda pair: pair[1])
    return [name for name, _ in found]


def make_five():
    directory = os.path.join(OUT, "pics_024")
    os.makedirs(directory, exist_ok=True)
    paths = []
    for name, rgb in PICTURES_5:
        path = os.path.join(directory, name)
        base.png(path, rgb)
        paths.append(path)
    return paths


def row_13():
    base.step("row 13 — the option takes the scenes, and a move still works")
    names = [name for name, _ in PICTURES_5]
    rows, page = open_content()
    if page is None:
        check("13: the fixture reached the page", False, f"{labels(rows)[:10]}")
        return
    push_pictures(make_five())
    rows = open_video_dialog(names)
    if rows is None:
        check("13: the prompt holds five pictures", False, f"{labels(dump())[:10]}")
        return
    rows = open_pass(rows)
    if rows is None:
        check("13: the pass opened", False, f"{labels(dump())[:12]}")
        return
    before = {name: pass021.cell_line(rows, name) for name in names}
    print(f"   the counts before the option: {before}")
    check("13: the pass opens with nothing assigned",
          set(before.values()) == {"0"}, f"{before}")

    if not tap(rows, "Auto assign scenes", label="the option's label"):
        check("13: the option's label is on the page", False,
              f"visible: {labels(rows)[:14]}")
        return
    time.sleep(1.5)
    rows = fresh_dump()
    if on_screen(rows, "Auto assign the scenes?"):
        # Something was assigned: answer the question the way the reader would.
        tap(rows, "Assign", label="the question's confirm")
        time.sleep(1.5)
        rows = fresh_dump()
    after = {name: pass021.cell_line(rows, name) for name in names}
    print(f"   the counts after the option:  {after}")
    check("13: the first three pictures take the three scenes — 2, 3, 1",
          [after[name] for name in names[:3]] == ["2", "3", "1"],
          f"{[after[name] for name in names[:3]]}")
    check("13: the last two hold nothing",
          [after[name] for name in names[3:]] == ["0", "0"],
          f"{[after[name] for name in names[3:]]}")
    check("13: every sentence of a scene is under its own picture",
          sum(int(v) for v in after.values()) == 6,
          f"{sum(int(v) for v in after.values())} sentences in the runs")

    # A move still works: the pictures the pairing left empty are the reader's to
    # reorder (FR-015), and a pairing never writes a run its rules would refuse.
    order_before = strip_names(rows, names)
    # A hold opens the picture large (021 D10), and the move lives in the
    # controls under it — the cell's own drag is what 020 shipped, not what 021
    # left the reader.
    if pass021.hold_only(names[4], seconds=1.6, label=f"{names[4]}'s cell") and \
            tap(fresh_dump(), "Move left", label="Move left"):
        time.sleep(0.9)
        moved = strip_names(fresh_dump(), names)
        print(f"   the strip before the move: {order_before}")
        print(f"   the strip after the move:  {moved}")
        check("13: a picture the option left empty still moves",
              moved != order_before, f"{order_before} → {moved}")
    else:
        check("13: a picture the option left empty still moves", False,
              f"visible: {labels(fresh_dump())[:10]}")

    rows = fresh_dump()
    if not tap(rows, "Done", label="Done"):
        check("13: Done answered the pass", False, f"{labels(rows)[:10]}")
        return
    time.sleep(1.5)
    rows = dump_until("pictures chosen")
    print(f"   the prompt after Done: {labels(rows)[:8]}")

    # And the label is **absent** where the content has no scene (FR-008): the
    # same page, a tag-free text.
    rows, page = open_content("scene_024_plain", "无场景样本", deleted(fixture_text()))
    if page is None:
        check("13: the tag-free content reached the page", False,
              f"{labels(rows)[:10]}")
        return
    push_pictures(make_five())
    rows = open_video_dialog(names)
    if rows is None:
        check("13: the prompt holds five pictures for the tag-free content", False,
              f"{labels(dump())[:10]}")
        return
    rows = open_pass(rows)
    if rows is None:
        check("13: the pass opened on the tag-free content", False,
              f"{labels(dump())[:12]}")
        return
    check("13: the option is absent for a content with no scene",
          not on_screen(rows, "Auto assign scenes"),
          f"visible: {labels(rows)[:14]}")
    tap(fresh_dump(), "Done", label="Done")
    time.sleep(1.2)
    unseed_fixture("scene_024_plain")


def row_14():
    base.step("row 14 — the render's frames carry no tag")
    names = [name for name, _ in PICTURES_5]
    rows, page = open_content()
    if page is None:
        check("14: the fixture reached the page", False, f"{labels(rows)[:10]}")
        return
    push_pictures(make_five())
    rows = open_video_dialog(names)
    if rows is None:
        check("14: the prompt holds five pictures", False, f"{labels(dump())[:10]}")
        return
    rows = open_pass(rows)
    if rows is None:
        check("14: the pass opened", False, f"{labels(dump())[:12]}")
        return
    tap(rows, "Auto assign scenes", label="the option")
    time.sleep(1.5)
    rows = fresh_dump()
    if on_screen(rows, "Auto assign the scenes?"):
        tap(rows, "Assign", label="the question's confirm")
        time.sleep(1.5)
    tap(fresh_dump(), "Done", label="Done")
    time.sleep(1.5)
    log = start_render(seconds=180)
    plan = base.render_plan(log)
    report = base.render_report(log)
    runs = video.render_runs(log)
    spans = base.spoken_spans(log)
    print(f"   the renderer's plan: {plan}")
    print(f"   the render's report: {report}")
    expected_sentences = len(app_sentences(masked(fixture_text())))
    check("14: the renderer names one slot per sentence of the read",
          plan is not None and plan[2] == expected_sentences,
          f"plan: {plan}, the read's own sentences: {expected_sentences}")
    check("14: every slot's span is one of the read's own sentences",
          len(spans) == expected_sentences,
          f"{len(spans)} slot spans, {expected_sentences} sentences")
    check("14: the file was written and reports its own frame count",
          report is not None and report[3] > 0, f"report: {report}")
    # The fixture stays: row 15 re-runs five closed features on tag-free text.


ROWS = {
    "10": row_10,
    "11": row_11,
    "12": row_12,
    "13": row_13,
    "14": row_14,
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ROWS:
        print("usage: klhu_walk_scene.py <%s>" % "|".join(ROWS))
        return 2
    base.preflight()
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.4)
    adb("shell", "input", "keyevent", "KEYCODE_BACK")
    time.sleep(0.4)
    os.makedirs(OUT, exist_ok=True)
    ROWS[sys.argv[1]]()
    failed = [name for name, ok, _ in base.RESULTS if not ok]
    print(f"\n{len(base.RESULTS) - len(failed)}/{len(base.RESULTS)} checks passed")
    for name in failed:
        print(f"   FAILED: {name}")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
