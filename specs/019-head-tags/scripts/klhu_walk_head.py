#!/usr/bin/env python3
"""klhu device walk — 019 quickstart rows 10, 11, 12 and 14.

Row 10: the page on the device — the dump carries no marker, the title's own
        words are painted and go to the engine as they are read, the range the
        app logs is the step's own, and the five rungs are captured.
Row 11: ▶ and ⏭ through the marked content — the highlight's sequence and the
        read's own ranges against the same text with the markers written as
        spaces, with no utterance carrying a marker.
Row 12: the video — the title's `text=` count, the ink box twice, the mixed slot,
        and the Chinese pair through the renderer's own lines.
Row 14: a bold body's comment measured on the page — the comment's ink height
        and the sentence's at each of the four sizes, 017's regular pair beside
        them.

The mechanics are 016's (`specs/016-sentence-reading/scripts/klhu_walk_step.py`),
which are 015's, 014's and 012's beneath them: one string per `adb shell` command,
`uiautomator dump` reads, `check(name, ok, detail)` with a PASS/FAIL summary and a
non-zero exit on failure. 017's own module is imported for the one thing only it
has: driving the appearance control and measuring ink.

019 adds only what is its own: its fixture, its own section reader (the fixture's
CONTENT starts with `# ` and carries `## ` as a subtitle, so 015's splitter — which
reads a `## ` line as a header — cannot read it), the ladder's five captures, and
the comment-versus-sentence height pair.

Usage:  python3 -u klhu_walk_head.py 10
        ADB_SERIAL=emulator-5554 python3 -u klhu_walk_head.py 10
        KLHU_REPO=~/Documents/GitHub/Projects/klhu KLHU_OUT=/tmp/klhu_out \\
            python3 -u klhu_walk_head.py 10
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.

A row is implemented here in the pass that walks it; `main` names the rows it does
not have yet rather than dispatching into a stub (014's own convention).
"""
import os
import re
import sys
import time

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
for _spec in ("016-sentence-reading", "017-bold-comment-size",
              "015-comment-tag", "011-reading-experience"):
    sys.path.insert(0, os.path.join(REPO, "specs", _spec, "scripts"))

import klhu_walk_step as stepper  # noqa: E402
import klhu_walk_bold as bold  # noqa: E402
import klhu_walk_comment as comment  # noqa: E402

adb = stepper.adb
dump = stepper.dump
check = stepper.check
step = stepper.step
cat = stepper.cat
shows = stepper.shows
labels = stepper.labels
start_app = stepper.start_app
wait_for = stepper.wait_for
fresh_prefs = stepper.fresh_prefs
device_now = stepper.device_now
logcat_since = stepper.logcat_since
speak_lines = stepper.speak_lines
painted_text = comment.painted_text
open_section = comment.open_section
press_read = stepper.press_read
wait_for_read_end = stepper.wait_for_read_end
ranges_since = stepper.ranges_since
logged_text = stepper.logged_text
step_of = stepper.step_of
screencap = stepper.screencap
experience = stepper.experience
RESULTS = stepper.RESULTS
LIBRARY = stepper.LIBRARY

FIXTURE = os.path.join(HERE, "klhu_head_fixture.txt")

# The fixture's own section keys. A header is a header only when its key is one
# of these: `main`'s content carries `## Greetings` as a SUBTITLE, which 015's
# leading-`## ` splitter would read as a section of its own.
KEYS = ("main", "spaced", "cjk", "control")


def fixture_sections():
    """The fixture's sections, by their known keys."""
    with open(FIXTURE, encoding="utf-8") as handle:
        text = handle.read()
    parts = re.split(r"(?m)^## (" + "|".join(KEYS) + r")\n", text)
    sections = {}
    for i in range(1, len(parts), 2):
        sections[parts[i]] = parts[i + 1].strip("\n")
    return sections


def check_fixture():
    """Every section, with its own line count — the fixture's drift guard."""
    sections = fixture_sections()
    for key in KEYS:
        text = sections.get(key)
        if text is None:
            check(f"fixture '{key}' is there", False, f"keys: {sorted(sections)}")
            continue
        print(f"   fixture '{key}': {len(text.splitlines())} lines, {len(text)} chars")
    check("the fixture carries its four sections", set(sections) == set(KEYS),
          f"keys: {sorted(sections)}")
    check("the spaced control is the marked main with the markers written out",
          len(sections["spaced"]) == len(sections["main"]),
          f"{len(sections['spaced'])} chars against {len(sections['main'])}")
    return sections


# ---------------------------------------------------------------------------
# row 10 — the page
# ---------------------------------------------------------------------------
def row_10():
    step("row 10 — the page paints the ladder and hands the engine no marker")
    sections = check_fixture()
    text = sections["main"]
    fresh_prefs()
    if open_section("main", cid="head_main", name="head", text=text) is None:
        return False
    start_app()
    rows = dump()
    if not shows(rows, "read"):
        check("10: the page opened with its toolbar", False,
              f"visible: {labels(rows)[:12]}")
        return False

    painted = painted_text(rows)
    print(f"   painted: {painted[:90]!r}")
    check("10: the page paints the title's own words (FR-005)",
          "Basic Spanish 1" in painted, f"painted: {painted[:90]!r}")
    check("10: the subtitle is painted too, as its own words",
          "Greetings" in painted, f"painted: {painted[:90]!r}")
    check("10: no marker is painted anywhere (FR-003)",
          "#" not in painted, f"painted: {painted[:90]!r}")

    # One ▶, and the app's own lines for it: the words and the range.
    adb("logcat", "-c")
    stamp = device_now()
    if not press_read():
        check("10: ▶ Read is on the page", False, "")
        return False
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= 1, seconds=40)
    speaks = speak_lines(logcat_since(stamp))
    ranges = ranges_since(stamp)
    quoted = [speak["text"] for speak in speaks]
    print(f"   spoken: {quoted}")
    print(f"   ranges: {ranges}")
    check("10: nothing spoken carries a marker (FR-004)",
          all("#" not in line for line in quoted), f"spoken: {quoted}")
    check("10: the title reached the engine as its own words (FR-004)",
          quoted and quoted[0] == logged_text("Basic Spanish 1"),
          f"spoken: {quoted} against {logged_text('Basic Spanish 1')!r}")
    check("10: the range is the step's own — 016's unit unmoved (FR-011)",
          ranges and ranges[0] == step_of(text, 0),
          f"the app read {ranges}, the step is {step_of(text, 0)}")
    wait_for_read_end()

    # The ladder, at the five pairs the row names: one capture each, and the ink
    # grows with the rung.
    regulars = dict(bold.REGULARS)
    boldfaces = dict(bold.FACES)
    sizes = bold.SIZES
    pairs = [
        (regulars["serif"], sizes["small"], "small"),
        (regulars["serif"], sizes["medium"], "medium"),
        (regulars["serif"], sizes["large"], "large"),
        (regulars["serif"], sizes["xlarge"], "xlarge"),
        (boldfaces["serif-bold"], sizes["xlarge"], "bold_xlarge"),
    ]
    shots = []
    for face, size, tag in pairs:
        if not bold.set_appearance(face, size):
            check(f"10: '{face}' at {size} is in force", False,
                  "the picker did not take it")
            return False
        cap = screencap(os.path.join(experience.OUT, f"019_row10_{tag}.png"))
        measured = bold.ink(cap)
        print(f"   {tag}: {measured['pixels']} ink px → {cap}")
        shots.append((tag, measured["pixels"]))
        check(f"10/{tag}: the page painted something to measure",
              measured["pixels"] > 0, f"{cap}")
    check("10: the ink grows with the rung (SC-001)",
          shots[0][1] < shots[1][1] < shots[2][1] < shots[3][1] <= shots[4][1],
          f"ink per rung: {shots}")
    return True


# ---------------------------------------------------------------------------
# row 11 — the read, against the spaced control
# ---------------------------------------------------------------------------
def drive_marked(text, tag, presses=2):
    """Seeds [text], presses ▶ [presses] times and then ⏭, and returns each
    press's own lines as `(ranges, spoken texts, the highlight's top row)`."""
    fresh_prefs()
    if open_section("main", cid="head_main", name="head", text=text) is None:
        return None
    start_app()
    log = []
    for i in range(presses):
        ranges, speaks = stepper.fresh_press()
        if ranges is None:
            check(f"11: ▶ press {i + 1} on the {tag} content", False, "")
            return None
        cap = screencap(os.path.join(experience.OUT, f"019_row11_{tag}_{i + 1}.png"))
        top, cells = stepper.painted_band(cap)
        print(f"   {tag} press {i + 1}: ranges={ranges} "
              f"spoken={[s['text'] for s in speaks]} → highlight top={top}, {cells} px")
        check(f"11/{tag}.{i + 1}: the step being read is painted (SC-004)",
              cells > 0, f"{cap} → {cells} yellow px")
        log.append((ranges, [s["text"] for s in speaks], top))
        wait_for_read_end()
    ranges, speaks = stepper.continue_read()
    if ranges is None:
        check(f"11: ⏭ on the {tag} content", False, "")
        return None
    print(f"   {tag} ⏭: ranges={ranges} spoken={[s['text'] for s in speaks]}")
    log.append((ranges, [s["text"] for s in speaks], None))
    return log


def row_11():
    step("row 11 — ▶ and ⏭ through the marked content against the spaced control")
    sections = check_fixture()
    marked = drive_marked(sections["main"], "marked")
    if marked is None:
        return False
    spaced = drive_marked(sections["spaced"], "spaced")
    if spaced is None:
        return False

    text = sections["main"]
    check("11: a ▶ press reads one step, and the steps are the content's own (FR-011)",
          [press[0] for press in marked[:2]] ==
          [[step_of(text, 0)], [step_of(text, 1)]],
          f"presses: {[press[0] for press in marked[:2]]} "
          f"against {[step_of(text, i) for i in (0, 1)]}")
    check("11: no utterance carries a marker, in any press (FR-004)",
          all("#" not in line for press in marked for line in press[1]),
          f"spoken: {[press[1] for press in marked]}")
    check("11: ⏭ read the rest of the content (SC-004)",
          marked[2][0] and marked[2][0][0][0] == step_of(text, 2)[0],
          f"⏭ read {marked[2][0]}, the third step starts at {step_of(text, 2)[0]}")
    check("11: the same text with the markers written out reads the same ranges",
          [press[0] for press in spaced] == [press[0] for press in marked],
          f"marked {[press[0] for press in marked]} against "
          f"spaced {[press[0] for press in spaced]}")
    check("11: and the same words — the markers alone differ",
          [line.strip() for press in spaced for line in press[1]] ==
          [line.strip() for press in marked for line in press[1]],
          f"marked {[press[1] for press in marked]} against "
          f"spaced {[press[1] for press in spaced]}")
    check("11: the highlight walked down the page, not backwards",
          all(press[2] is not None for press in marked[:2]) and
          marked[0][2] <= marked[1][2],
          f"the bands' top rows: {[press[2] for press in marked[:2]]}")
    return True


# ---------------------------------------------------------------------------
# row 14 — a bold body's comment, measured on the page
# ---------------------------------------------------------------------------
# 017's own fixture for the comparison: the comment repeats its sentence's own
# word, so the two lines hold the SAME glyphs and their ink heights measure the
# size alone (017's row 10 records why the fixture is built this way).
SAME_TEXT = "Hola.\n\n[注] Hola."


def measure_pair(size, face_label, tag):
    """One appearance: the sentence's ink height and the comment's."""
    if not bold.set_appearance(face_label, bold.SIZES[size]):
        check(f"14: '{face_label}' at {size} is in force", False,
              "the picker did not take it")
        return None
    path = screencap(os.path.join(experience.OUT, f"019_row14_{tag}_{size}.png"))
    bands = bold.ink_lines(path, band=bold.CONTENT_BAND)
    if len(bands) < 2:
        check(f"14/{tag} {size}: the page paints the sentence and the comment",
              False, f"{len(bands)} ink bands: {bands}")
        return None
    sentence, comment_line = bands[0], bands[-1]
    heights = (sentence[1] - sentence[0], comment_line[1] - comment_line[0])
    print(f"   14/{tag} {size}: lines {bands} — the sentence {heights[0]}px, "
          f"the comment {heights[1]}px → {path}")
    return heights


def row_14():
    step("row 14 — a bold body's comment on the page, against 017's regular pair")
    fresh_prefs()
    if comment.open_section("same", cid="head_same", name="same",
                            text=SAME_TEXT) is None:
        return False
    start_app()
    time.sleep(1.2)

    regulars = dict(bold.REGULARS)
    faces = dict(bold.FACES)

    bold_pairs = {}
    for size in ("small", "medium", "large", "xlarge"):
        heights = measure_pair(size, faces["bold"], "bold")
        if heights is None:
            return False
        bold_pairs[size] = heights
        check(f"14/bold {size}: a bold body's comment is the sentence's own size (FR-015)",
              abs(heights[1] - heights[0]) <= 2,
              f"comment {heights[1]}px against the sentence {heights[0]}px")

    regular_pairs = {}
    for size in ("medium", "small"):
        heights = measure_pair(size, regulars["default"], "regular")
        if heights is None:
            return False
        regular_pairs[size] = heights
        check(f"14/regular {size}: a regular body's comment is still smaller — 017's own measurement",
              heights[1] < heights[0],
              f"comment {heights[1]}px against the sentence {heights[0]}px")

    check("14: the comment grows with the size in both faces (SC-007's floor)",
          regular_pairs["small"][1] < regular_pairs["medium"][1] and
          bold_pairs["small"][1] < bold_pairs["medium"][1] <
          bold_pairs["large"][1] <= bold_pairs["xlarge"][1],
          f"regular {regular_pairs}, bold {bold_pairs}")
    return True


# ---------------------------------------------------------------------------
# row 12 — the video's frames
# ---------------------------------------------------------------------------
TITLE = "Basic Spanish 1"
SUB = "Greetings"
BODY = "Hola. Adiós."
COMMENT = "How are you?"


def face_label(face):
    """The control's own label for a record value, regular or bold."""
    faces = dict(bold.REGULARS)
    faces.update(dict(bold.FACES))
    return faces[face]


def dismiss_review():
    """Clears a finished render's review screen.

    A render ends on 'Discard / Share / Save', which covers the page: the next
    appearance change has no control to tap until it is dismissed (015's
    `render_one` does this at its own start, but the review appears only once
    the render has finished — i.e. after this driver's picker step).
    """
    rows = dump()
    if stepper.video.on_screen(rows, "Discard"):
        stepper.video.tap(rows, "Discard", label="the earlier review")
        time.sleep(1.5)


_RENDERS = []


def render_slot(face, size, where):
    """One render at one appearance, and the first slot's own line plus its box.

    A **clean relaunch** stands between two renders in one run: dismissing the
    finished render's review screen is not enough — the second render's aspect
    prompt opens and `Start` is tapped, and the renderer's completion line never
    comes (300 s, twice, at two different faces). Every other row in this walk
    (015's and 017's drivers included) renders once per run and never meets it.
    """
    if _RENDERS:
        adb("shell", "am", "force-stop", comment.PKG)
        start_app()
        time.sleep(1.5)
    dismiss_review()
    if not bold.set_appearance(face_label(face), bold.SIZES[size]):
        check(f"{where}: '{face_label(face)}' at {size} is in force", False,
              "the picker did not take it")
        return None
    result = comment.render_one(where)
    if result is None:
        check(f"{where}: the render produced a file", False,
              "render_one returned nothing")
        return None
    dest, frames, runs, _account, _ms = result
    run = comment.slot_of(runs)
    if not run:
        check(f"{where}: the renderer's own line is in the log", False,
              "no slot line found")
        return None
    w, h = comment.PICK_WH
    got = comment.box_of_frame(dest, run["start"], w, h)
    if got is None:
        check(f"{where}: the slot's first frame was read back", False,
              "box_of_frame returned nothing")
        return None
    band, outside, box = got
    print(f"   {where}: slot 0 text={run['text']} span={run['span_start']}..{run['span_end']} "
          f"frames={run['frames']}/{frames} ink box={box} (w {box[2] - box[0]}px, "
          f"h {box[3] - box[1]}px) band={band} outside={outside} → {dest}")
    check(f"{where}: nothing outside the column, no highlight band in the frame",
          band == 0 and outside == 0, f"band={band} outside={outside}")
    _RENDERS.append(where)
    return run, box, len(runs)


def row_12():
    step("row 12 — the video: the title's own text, the rung on the frame, the mixed slot")
    sections = check_fixture()

    fresh_prefs()
    if open_section("main", cid="head_main", name="head", text=sections["main"]) is None:
        return False
    start_app()

    shots = {}
    for face, size, tag in (("serif", "small", "small"),
                            ("serif", "xlarge", "xlarge"),
                            ("serif-bold", "xlarge", "bold_xlarge")):
        got = render_slot(face, size, f"12/{tag}")
        if got is None:
            return False
        shots[tag] = got

    run, box, slots = shots["xlarge"]
    check("12: the title's slot holds the title's own characters, marker excluded (FR-013)",
          run["text"] == len(TITLE), f"text={run['text']}, the title is {len(TITLE)} chars")
    check("12: the slot's span is the words' own, in content offsets (FR-011)",
          (run["span_start"], run["span_end"]) == (2, 17),
          f"span={run['span_start']}..{run['span_end']}")
    small_box = shots["small"][1]
    check("12: the rung is carried onto the frame — a bigger rung paints a taller block (FR-006)",
          (box[3] - box[1]) > (small_box[3] - small_box[1]),
          f"xlarge {box[3] - box[1]}px against small {small_box[3] - small_box[1]}px")
    bold_box = shots["bold_xlarge"][1]
    check("12: a bold face at the same rung paints a wider block (the weight reaches the frame)",
          (bold_box[2] - bold_box[0]) >= (box[2] - box[0]),
          f"bold {bold_box[2] - bold_box[0]}px against regular {box[2] - box[0]}px")

    # The mixed slot: the sentence with its comment riding it, one block.
    mixed = None
    runs = None
    # 015's rule decides which sentence the comment rides: the last non-comment
    # sentence that starts before its tag — here `Adiós.`, the paragraph's SECOND
    # sentence (the resolver cuts `Hola. Adiós.` in two), so the block is
    # `Adiós.` + the newline + the comment. The marker is in neither part.
    mixed_text = len("Adiós.") + 1 + len(COMMENT)
    result = comment.render_one("12/mixed")
    if result is not None:
        runs = result[2]
        for slot in range(len(runs)):
            entry = comment.slot_of(runs, slot)
            if entry and entry["text"] == mixed_text:
                mixed = entry
                break
    check("12: the mixed slot paints the sentence AND its comment, no tag (FR-013)",
          mixed is not None,
          f"expected a slot of {mixed_text} chars ({len('Adiós.')} + the newline + "
          f"{len(COMMENT)}) in {len(runs) if runs else 0} runs")
    if mixed:
        print(f"   12/mixed: slot {mixed['slot']} text={mixed['text']} "
              f"span={mixed['span_start']}..{mixed['span_end']}")

    # The Chinese pair: the marker is elided there too, in both faces.
    for face in ("default", "bold"):
        fresh_prefs()
        if open_section("cjk", cid="head_cjk", name="head-cjk",
                        text=sections["cjk"]) is None:
            return False
        start_app()
        got = render_slot(face, "medium", f"12/cjk_{face}")
        if got is None:
            return False
        run, box, _slots = got
        # The step reaches over the comment when the read covers it (016's own
        # rule), so the block is the title's 5 characters + the newline + the
        # comment's 3 — and NOT the marker's 2, which is this check's whole point.
        expected = len("今日嘅天气") + 1 + len("你好。")
        check(f"12/cjk {face}: the Chinese title carries its own characters, marker excluded",
              run["text"] == expected,
              f"text={run['text']} against {expected} "
              f"(5 own + the newline + the comment's 3; the marker's 2 excluded)")
        check(f"12/cjk {face}: the slot's span is the words' own — the marker is not in it",
              (run["span_start"], run["span_end"]) == (2, 7),
              f"span={run['span_start']}..{run['span_end']}")
        check(f"12/cjk {face}: the frame painted ink", box[3] > box[1] and box[2] > box[0],
              f"ink box={box}")
    return True


ROWS = {
    "10": row_10,
    "11": row_11,
    "14": row_14,
    "12": row_12,
}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(f"usage: {os.path.basename(__file__)} {'|'.join(sorted(ROWS))}")
        missing = [r for r in ("10", "11", "12", "14") if r not in ROWS]
        if missing:
            print(f"rows this walk still owes: {', '.join(missing)}")
        sys.exit(2)
    ROWS[sys.argv[1]]()
    failed = [row[0] for row in RESULTS if not row[1]]
    print(f"\nRESULT: {'PASS' if not failed else 'FAIL'} "
          f"({len(RESULTS) - len(failed)}/{len(RESULTS)})")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
