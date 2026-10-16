#!/usr/bin/env python3
"""klhu device walk — 016 quickstart rows 5-11.

Row 5: the stepper on the reader's own shape — three presses read one sentence each
       (the title, then the paragraph's two sentences) and the fourth reads nothing,
       clears the highlight and says nothing.
Row 6: the comment half — one press reads the sentence AND its comment, and the next
       press starts at the sentence after the comment.
Row 7: ⏭ after a step reads only the sentences the steps have not.
Row 8: the clean relaunch — nothing comes back, and no `read_position_*` record exists.
Row 9: a render from a step's position (012's machinery).
Row 15: the page away from the top — ▶ brings the sentence it reads into view
       before it is spoken (the reader's own report of 2026-10-16).

The mechanics are 015's (`specs/015-comment-tag/scripts/klhu_walk_comment.py`), which
are 014's and 012's beneath it: one string per `adb shell` command, `uiautomator dump`
reads, `tap_any(rows, key)` against `L`, `check(name, ok, detail)` with a PASS/FAIL
summary and a non-zero exit on failure. 016 adds only what is its own: its fixture, the
per-press `klhu read range` + `klhu speak` pairs, and the page's own yellow rows (011's
`screencap`/`yellow_rows`, borrowed for the highlight this feature leaves behind).

Usage:  python3 klhu_walk_step.py 5
        ADB_SERIAL=emulator-5554 python3 klhu_walk_step.py 5
        KLHU_REPO=~/Documents/GitHub/Projects/klhu KLHU_OUT=/tmp/klhu_out \\
            python3 klhu_walk_step.py 5
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.

Run a row with `python3 -u`: the row prints its progress and its evidence as it goes.

A row is implemented here in the pass that walks it; `main` names the rows it does not
have yet rather than dispatching into a stub (014's own convention).
"""
import os
import re
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "015-comment-tag", "scripts"))
sys.path.insert(0, os.path.join(REPO, "specs", "011-reading-experience", "scripts"))

# 015's module owns the device mechanics (014's and 012's beneath it).
import klhu_walk_comment as comment  # noqa: E402
import klhu_walk_experience as experience  # noqa: E402
import time  # noqa: E402

adb = comment.adb
dump = comment.dump
tap = comment.tap
find = comment.find
labels = comment.labels
show = comment.show
step = comment.step
check = comment.check
cat = comment.cat
seed = comment.seed
start_app = comment.start_app
wait_for = comment.wait_for
fresh_prefs = comment.fresh_prefs
device_now = comment.device_now
logcat_since = comment.logcat_since
speak_lines = comment.speak_lines
tap_any = comment.tap_any
shows = comment.shows
content_node = comment.content_node
LIBRARY = comment.LIBRARY
PREFS = comment.PREFS
RESULTS = comment.RESULTS

video = comment.video

# The artifacts' directory (012's rows assume it exists; a fresh host has none).
os.makedirs(experience.OUT, exist_ok=True)
os.makedirs(video.OUT, exist_ok=True)
screencap = experience.screencap
yellow_rows = experience.yellow_rows

L = dict(comment.L)

# The record the retired store wrote, by the page's own content key.
KEY = "read_position_step_main"
prefs_value = comment.prefs_value
prefs_xml = comment.dialogue.prefs_xml
PKG = comment.PKG

FIXTURE = os.path.join(HERE, "klhu_step_fixture.txt")

# What each fixture section holds, in the app's own units (FR-006's rule: the
# sentences are `sentenceRanges`', a paragraph's end being a sentence's end).
SECTIONS = ("main", "comment", "inline_comment", "dialogue")


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


def open_section(section, cid=None, name=None):
    """Pushes one fixture section into the library and opens it."""
    text = fixture_sections()[section]
    cid = cid or f"step_{section}"
    if seed(cid, name or section, text) is None:
        check(f"{section}: the fixture reached the device", False,
              "device_write failed")
        return None
    pushed = cat(f"{LIBRARY}/content/contents/{cid}.txt").decode("utf-8", "replace")
    if pushed != text:
        check(f"{section}: the fixture reached the device, whole", False,
              f"{len(pushed)} chars read back, {len(text)} written")
        return None
    time.sleep(1)
    return text


RANGE_RE = re.compile(r"klhu read range: (\d+)\.\.(\d+)")


def logged_text(text):
    """The app's own form of an utterance on its `klhu speak` line.

    `lib/reader_service.dart`'s `_logPrefix`: whitespace collapsed, and anything
    longer than 24 characters elided with `...` — the line is evidence of which
    unit went to the engine, not of the whole text.
    """
    one_line = re.sub(r"\s+", " ", text)
    return one_line if len(one_line) <= 24 else one_line[:24] + "..."


def ranges_since(stamp):
    """Every `klhu read range: a..b` the app logged since [stamp], in order."""
    return [(int(m.group(1)), int(m.group(2)))
            for line in logcat_since(stamp).splitlines()
            for m in [RANGE_RE.search(line)] if m]


def wait_for_read_end(seconds=30):
    """Waits for the read in flight to finish, by the page's own state.

    While a read plays the toolbar offers Pause in place of the read actions
    (011), so the button being back is the end of the read — no sleep, and no
    guess about how long an utterance takes.
    """
    return wait_for(lambda: shows(dump(), "read", exact=True), seconds=seconds)


def press_read(label="Read"):
    """One ▶ Read press — the toolbar button at the foot of the page.

    The band matters: the app bar draws the app's own name beside the read
    buttons' words on some states, and an unbounded search taps the title.
    """
    rows = dump()
    for text in L["read"]:
        if find(rows, text, exact=True, below=1800):
            return tap(rows, text, label=label, exact=True)
    print(f"   NOT FOUND (the toolbar's own button): {labels(rows)[:14]}")
    return False


def press_and_read(stamp, seconds=25):
    """Presses ▶ once and reads BOTH of the app's own lines for it.

    The range line is logged when the read is resolved and the `klhu speak`
    lines as the service hands each utterance to the engine, so the second wait
    is what makes the pair comparable.
    """
    wait_for(lambda: len(ranges_since(stamp)) >= 1, seconds=seconds)
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= units,
             seconds=seconds)
    return ranges_since(stamp), speak_lines(logcat_since(stamp))


def step_of(text, n, comments_read=False):
    """The n-th step of [text] (0-based), as the contract defines one.

    The steps are the app's sentence ranges with a comment's own characters left
    out (`stepRanges`), and a step of an owning sentence reaches over its
    comment's span when the comments are being read (`stepEnd`) — computed here
    from the fixture's own text instead of trusted to the app.
    """
    paragraphs = [p for p in text.split("\n\n") if p.strip()]
    steps = []
    for paragraph in paragraphs:
        body = paragraph
        tag = body.find("[")
        if tag >= 0:
            body = body[:tag]
        for part in re.findall(r"[^.!?。！？]+[.!?。！？]*", body):
            part = part.lstrip()
            if part:
                at = text.index(part, steps[-1][1] if steps else 0)
                steps.append((at, at + len(part)))
    return steps[n]


def painted_band(cap):
    """The highlight's own band, from the page's yellow rows: (top, cells)."""
    rows = yellow_rows(cap)
    if not rows:
        return None, 0
    return min(rows), sum(rows.values())


def page_carries_a_message(rows):
    """Whether any of the strings a message would use is painted."""
    words = ("Nothing left to read", "没有可朗读", "没有任何",
             "Select a sentence", "请先选择")
    painted = " ".join((r["desc"] or r["text"]) for r in rows)
    return [w for w in words if w in painted]


def fresh_press(label="Read", units=1, seconds=25):
    """Clears the log, presses ▶ once, and returns the app's own lines for it.

    The log is cleared per press: this window is the app's evidence for THIS
    press, and a stale line from the press before it reads as a second utterance
    of this one (the first run of row 6 did exactly that).
    """
    adb("logcat", "-c")
    stamp = device_now()
    if not press_read(label):
        return None, None
    wait_for(lambda: len(ranges_since(stamp)) >= 1, seconds=seconds)
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= units,
             seconds=seconds)
    return ranges_since(stamp), speak_lines(logcat_since(stamp))


def page_node(needle="A quiet morning"):
    """The painted content node: 015's own finder keys off the comment fixture's
    text, so this feature finds its own (the node's own box, from the raw tree)."""
    for node in comment.video.raw_nodes():
        if needle in (node["desc"] or node["text"]):
            return node
    return None


def content_line_tap(fraction=0.35):
    """A TAP inside the painted text (not a long press): the gesture 010's rule is
    about, and the one that wrote the position down until this feature."""
    node = page_node()
    if node is None:
        return False
    y = node["y"] - node["h"] // 2 + int(node["h"] * fraction)
    adb("shell", "input", "tap", str(node["x"] + 10), str(y))
    print(f"   tap the text @{node['x'] + 10},{y} "
          f"(block {node['w']}x{node['h']} at {node['x']},{node['y']})")
    time.sleep(0.6)
    return True


def continue_read(units=1, seconds=45):
    """⏭ Continue Read once, with the app's own lines for it."""
    adb("logcat", "-c")
    stamp = device_now()
    if not tap_any(dump(), "continue", label="Continue Read"):
        return None, None
    wait_for(lambda: len(ranges_since(stamp)) >= 1, seconds=seconds)
    wait_for(lambda: len(speak_lines(logcat_since(stamp))) >= units,
             seconds=seconds)
    return ranges_since(stamp), speak_lines(logcat_since(stamp))


def row_7():
    step("row 7 — ⏭ after a step reads only the sentences the steps have not")
    fresh_prefs()
    text = open_section("main")
    if text is None:
        return False
    start_app()

    # Two steps: the title, then the paragraph's first sentence. The highlight
    # then sits on the third step — the sentence ⏭ must start from.
    for i in range(2):
        ranges, speaks = fresh_press()
        if ranges is None:
            check(f"7: press {i + 1} of the two steps", False, "")
            return False
        print(f"   step {i + 1}: ranges={ranges} "
              f"spoken={[s['text'] for s in speaks]}")
        wait_for_read_end()

    third = step_of(text, 2)
    ranges, speaks = continue_read()
    print(f"   ⏭: ranges={ranges} spoken={[s['text'] for s in speaks]}")
    check("7: ⏭ starts at the sentence the steps stopped on (SC-003)",
          ranges == [third], f"⏭ read {ranges}, the third step is {third}")
    check("7: and it reads only what the steps have not — once, in order",
          [s["text"] for s in speaks] == [logged_text(text[third[0]:third[1]])],
          f"spoken: {[s['text'] for s in speaks]}")
    return True


def row_8():
    step("row 8 — the clean relaunch: nothing comes back, and nothing was stored")
    fresh_prefs()
    text = open_section("main")
    if text is None:
        return False
    start_app()

    # (a) after a STEP: the position is in force on screen and nothing is
    # stored, so a relaunch cannot bring anything back.
    ranges, speaks = fresh_press()
    if ranges is None:
        check("8[a]: the step's own press", False, "")
        return False
    wait_for_read_end()
    stored = prefs_value(KEY)
    print(f"   after a step: {KEY} = {stored!r}")
    check("8[a]: a step writes no position down (FR-007)",
          stored is None, f"the store holds {stored!r}")
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    start_app()
    cap = screencap(os.path.join(experience.OUT, "016_row8_step_relaunch.png"))
    top, cells = painted_band(cap)
    check("8[a]: the relaunch paints no highlight", cells == 0,
          f"{cells} yellow px ({cap})")
    ranges, speaks = continue_read(units=3)
    print(f"   ⏭ after the relaunch: ranges={ranges}, {len(speaks)} utterances")
    check("8[a]: and ⏭ reads from the first sentence (010 FR-005)",
          bool(ranges) and ranges[0][0] == 0, f"⏭ read {ranges}")

    # (b) after a TAP — the site that wrote the record until this feature.
    wait_for_read_end()
    if not content_line_tap():
        check("8[b]: the text is on the page", False,
              f"visible: {labels(dump())[:12]}")
        return False
    cap = screencap(os.path.join(experience.OUT, "016_row8_tap.png"))
    top, cells = painted_band(cap)
    check("8[b]: the tap's own place is painted, in force on screen",
          cells > 0, f"{cells} yellow px ({cap})")
    stored = prefs_value(KEY)
    whole = prefs_xml()
    print(f"   after a tap: {KEY} = {stored!r}; any read_position key anywhere: "
          f"{'read_position' in whole}")
    check("8[b]: a tap writes nothing down either (decision 5)",
          stored is None and "read_position" not in whole,
          f"key {stored!r}, a read_position key in the store: "
          f"{'read_position' in whole}")
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    start_app()
    cap = screencap(os.path.join(experience.OUT, "016_row8_tap_relaunch.png"))
    top, cells = painted_band(cap)
    check("8[b]: the relaunch after a tap paints no highlight either (FR-007)",
          cells == 0, f"{cells} yellow px ({cap})")
    return True



def row_5():
    step("row 5 — the stepper: three presses, then a fourth that is silent")
    fresh_prefs()
    text = open_section("main")
    if text is None:
        return False
    start_app()
    rows = dump()
    if not shows(rows, "read"):
        check("5: the page opened with its toolbar", False,
              f"visible: {labels(rows)[:12]}")
        return False

    bands = []
    for i in range(3):
        expected = text[step_of(text, i)[0]:step_of(text, i)[1]]
        ranges, speaks = fresh_press()
        if ranges is None:
            check(f"5.{i + 1}: ▶ Read is on the page", False, "")
            return False
        print(f"   press {i + 1}: ranges={ranges} "
              f"spoken={[s['text'] for s in speaks]}")
        check(f"5.{i + 1}: the press read the step's own range (SC-001)",
              ranges == [step_of(text, i)],
              f"the app read {ranges}, the step is {step_of(text, i)}")
        check(f"5.{i + 1}: exactly one sentence was spoken, and it is the step's",
              [s["text"] for s in speaks] == [logged_text(expected)],
              f"spoken: {[s['text'] for s in speaks]} for {logged_text(expected)!r}")
        cap = screencap(os.path.join(experience.OUT, f"016_row5_press{i + 1}.png"))
        top, cells = painted_band(cap)
        print(f"   press {i + 1}: the highlight's top row {top}, {cells} yellow px")
        check(f"5.{i + 1}: the step being read is painted (SC-002)", cells > 0,
              f"{cap} → {cells} yellow px")
        bands.append(top)
        # The read finishes by itself before the next press — the advance is what
        # the NEXT press then reads, so nothing overlaps here.
        wait_for_read_end()

    check("5: the highlight stayed on the page, below the title, from press 1 on",
          all(b is not None for b in bands) and bands == sorted(bands),
          f"the three bands' top rows: {bands}")

    # The text has been read to its end: the LAST step's own press is the one
    # that ends it, and it ends with nothing highlighted and nothing said
    # (FR-008, SC-002) — the paragraph's own last sentence is step 3.
    wait_for_read_end()
    time.sleep(1)
    cap = screencap(os.path.join(experience.OUT, "016_row5_end.png"))
    top, cells = painted_band(cap)
    leftovers = page_carries_a_message(dump())
    print(f"   after press 3: yellow={cells}, painted message: {leftovers}")
    check("5.4: the text's end left nothing highlighted (FR-008, SC-002)",
          cells == 0, f"{cells} yellow px")
    check("5.4: and the page says nothing at all (FR-008)",
          leftovers == [], f"painted: {leftovers}")

    # A further press is a fresh start, not a dead button: with nothing in force
    # ▶ takes the text's first step again (FR-001) — the end is not a mode.
    ranges, speaks = fresh_press()
    if ranges is None:
        check("5.5: ▶ Read is still on the page after the end", False, "")
        return False
    print(f"   press 4: ranges={ranges} spoken={[s['text'] for s in speaks]}")
    check("5.5: a press after the end starts at the first sentence again (FR-001)",
          ranges == [step_of(text, 0)]
          and [s["text"] for s in speaks]
          == [logged_text(text[step_of(text, 0)[0]:step_of(text, 0)[1]])],
          f"ranges: {ranges}, speak: {[s['text'] for s in speaks]}")
    return True


def row_6():
    step("row 6 — a step is the sentence plus its comment")
    fresh_prefs()
    text = open_section("comment")
    if text is None:
        return False
    start_app()

    # A step with a comment is TWO utterances (015): wait for both, or the
    # comment's own line arrives after the window is read.
    ranges, speaks = fresh_press(units=2)
    if ranges is None:
        check("6: ▶ Read is on the page", False, f"visible: {labels(dump())[:12]}")
        return False
    print(f"   press 1: ranges={ranges} "
          f"spoken={[(s['text'], s['comment']) for s in speaks]}")
    check("6: the first press read the sentence and its comment (FR-005)",
          [s["text"] for s in speaks] == ["Hola.", "How are you?"],
          f"spoken: {[s['text'] for s in speaks]}")
    check("6: the comment's own utterance carries comment=1 (015's field)",
          [s["comment"] for s in speaks] == [False, True],
          f"flags: {[s['comment'] for s in speaks]}")

    wait_for_read_end()
    ranges, speaks = fresh_press()
    if ranges is None:
        check("6: ▶ Read is on the page for the second press", False, "")
        return False
    print(f"   press 2: ranges={ranges} spoken={[s['text'] for s in speaks]}")
    check("6: the next press starts at the sentence AFTER the comment (SC-004)",
          [s["text"] for s in speaks] == ["Adiós."],
          f"spoken: {[s['text'] for s in speaks]} — and the range {ranges} "
          f"against the sentence at {text.index('Adiós.')}")
    check("6: that range is the sentence after the comment, not a character of it",
          ranges and ranges[0][0] == text.index("Adiós."),
          f"the app read {ranges}, the sentence starts at {text.index('Adiós.')}")

    # The inline shape: a comment between two sentences of one paragraph rides
    # the sentence before it, and the press after it reads the sentence after.
    inline = open_section("inline_comment")
    if inline is None:
        return False
    start_app()
    ranges, speaks = fresh_press()
    print(f"   inline press 1: spoken={[s['text'] for s in speaks]}")
    check("6: in the inline shape the comment rides its owner, not the first press",
          [s["text"] for s in speaks] == ["Hola."],
          f"spoken: {[s['text'] for s in speaks]}")
    wait_for_read_end()
    ranges, speaks = fresh_press(units=2)
    print(f"   inline press 2: spoken={[(s['text'], s['comment']) for s in speaks]}")
    check("6: the next press reads the sentence after it and its own comment",
          [(s["text"], s["comment"]) for s in speaks]
          == [("Adiós.", False), ("Fine.", True)],
          f"spoken: {[(s['text'], s['comment']) for s in speaks]}")
    return True


def row_9():
    step("row 9 — a render from a step's position (012's own path)")
    fresh_prefs()
    text = open_section("main")
    if text is None:
        return False
    start_app()

    # ONE step: the highlight — and with it the position — is on the paragraph's
    # first sentence. That non-zero position is the case 011's 2026-10-09
    # amendment left unwalked (`lib/video_timeline.dart:128`).
    #
    # **Re-cut 2026-10-16.** The three checks below used to ask the render to
    # *start* at that non-zero position — 012's FR-004. **020's FR-017 superseded
    # that half** (the reader's own rule of 2026-10-14: a video is the whole
    # content, and the page's position "MUST NOT move a video's start"), and the
    # app has rendered from the content's first sentence since; the row was left
    # asserting the superseded expectation, which is why it read `FAIL (8/11)` for
    # as long as it did. What it pins now is the rule in force **and** the
    # supersession itself: the press still leaves a non-zero position in force, and
    # the render's first slot is the content's own first sentence all the same.
    ranges, speaks = fresh_press()
    if ranges is None:
        check("9: the step's own press", False, "")
        return False
    second = step_of(text, 1)
    check("9: the press read the first step and left the SENTENCE AFTER it in force",
          ranges == [step_of(text, 0)] and second[0] != 0,
          f"the press read {ranges} (the first step is {step_of(text, 0)}); "
          f"the position in force is {second}")
    wait_for_read_end()

    rows = dump()
    if video.on_screen(rows, "Discard"):
        video.tap(rows, "Discard", label="the earlier review")
        time.sleep(1.5)
    result = video.render("9/step", comment.PICK)
    if not result:
        check("9: the render produced a file", False,
              f"visible: {labels(dump())[:10]}")
        return False
    path, ms, size, frames, _wall = result
    dest = os.path.join(experience.OUT, "016_row9_step.mp4")
    _data, pulled = video.pull(path, dest)
    check("9: the file came off the device and is not empty",
          pulled and size > 10000, f"{size}B → {dest}")

    runs = video.render_runs(video.logcat())
    groups = video.slot_groups(runs)
    if not runs:
        check("9: the renderer's own lines are in the log", False, "")
        return False
    first = groups[0][0]
    print(f"   the file's first slot: span={first['span_start']}..{first['span_end']} "
          f"text={first['text']} frames={first['frames']}")
    first_step = step_of(text, 0)
    check("9: the render opens on the content's own first sentence, whatever the page's "
          "position is (020 FR-017, which superseded 012 FR-004's other half)",
          first["span_start"] == first_step[0],
          f"slot 0's span starts at {first['span_start']}, the content's first sentence "
          f"is at {first_step[0]} — while the position in force is {second[0]}, which "
          f"must not move it")
    check("9: and that slot's span is that first sentence",
          first["span_start"] == first_step[0] and first["span_end"] == first_step[1],
          f"span {first['span_start']}..{first['span_end']} against {first_step}")
    check("9: the text it paints is that sentence's own characters (no tag, no padding)",
          first["text"] == len(text[first_step[0]:first_step[1]]),
          f"text={first['text']} for the first sentence's "
          f"{len(text[first_step[0]:first_step[1]])}")
    return True


def row_15():
    """The reader's own report of 2026-10-16: with the page away from the top and
    nothing highlighted, ⏭ Continue Read scrolls to the first sentence and reads
    it, while ▶ Read reads it **with the page where it was** — the reveal arriving
    only after that sentence, when the highlight advances to the next one.

    FR-012 asks the page to bring the sentence a step highlights into view, and
    011's own rule asks that the sentence being read be visible. What is checked
    here is the page's own paint while the sentence is spoken (011's
    `yellow_rows`): the dump can show neither the scroll offset nor the highlight.
    """
    step("row 10 — away from the top, ▶ brings the sentence it reads into view "
         "before it is spoken (FR-012)")
    fresh_prefs()
    # A content taller than the page at X-Large: 016's own paragraph, twelve times.
    paragraph = fixture_sections()["main"].split("\n\n")[-1].strip()
    text = "\n\n".join([paragraph] * 12) + "\n"
    first_step = step_of(text, 0)
    if seed("step_lead", "lead", text) is None:
        check("15: the long fixture reached the device", False,
              "device_write failed")
        return False
    start_app()
    experience.set_xlarge(dump())
    time.sleep(1.2)

    def away_from_the_top():
        """Swipes the reading area up, so its first sentence is off screen."""
        adb("shell", "input", "swipe", "540", "1500", "540", "400", "500")
        time.sleep(1.5)

    def away_from_the_read():
        """Ends the read in flight and clears the highlight (016 FR-009), so the
        next press starts from the same clean state as the one before it."""
        if not tap_any(dump(), "stop", label="Stop"):
            wait_for_read_end()
        time.sleep(1.0)

    def press_and_watch(key, label, press):
        """Presses a read button and takes stills **while its read is in flight**.

        Returns the app's own `klhu read range` lines for the press and the
        highlight's own band in each frame — the page's paint, which is what says
        whether the sentence being read is on screen.
        """
        adb("logcat", "-c")
        stamp = device_now()
        if not press():
            return None, []
        wait_for(lambda: len(ranges_since(stamp)) >= 1, seconds=15)
        bands = []
        for _ in range(3):
            cap = screencap(os.path.join(
                experience.OUT, f"016_row15_{key}_{len(bands)}.png"))
            bands.append(painted_band(cap))
            time.sleep(0.4)
        return ranges_since(stamp), bands

    # The control: the same steps on ⏭, which is what ships and what the reader
    # says works.
    away_from_the_top()
    control, control_bands = press_and_watch(
        "continue", "⏭ Continue Read",
        lambda: tap_any(dump(), "continue", label="⏭ Continue Read"))
    if control is None:
        check("15: ⏭ Continue Read is on the page", False,
              f"visible: {labels(dump())[:12]}")
        return False
    print(f"   ⏭ ranges={control} | frames (top, yellow px): {control_bands}")
    check("15: the control — ⏭ starts at the first sentence and it is painted "
          "while it is spoken",
          control[0][0] == 0 and any(cells > 0 for _top, cells in control_bands),
          f"ranges={control}, bands={control_bands}")
    away_from_the_read()

    # The subject: the reader's own press, from the same state. `press_read`
    # carries the band that keeps the app bar's own title out of the search.
    away_from_the_top()
    subject, subject_bands = press_and_watch("read", "▶ Read",
                                             lambda: press_read("▶ Read"))
    if subject is None:
        check("15: ▶ Read is on the page", False,
              f"visible: {labels(dump())[:12]}")
        return False
    print(f"   ▶ ranges={subject} | frames (top, yellow px): {subject_bands}")
    check("15: ▶ read the first step too (the reader's own steps)",
          subject[:1] == [first_step],
          f"the app read {subject}, the first step is {first_step}")
    check("15: and it was painted on screen while it was spoken — the page had "
          "brought it into view before speaking it (FR-012)",
          any(cells > 0 for _top, cells in subject_bands),
          f"bands={subject_bands} — the reader's own report was that no frame "
          f"of this press showed the highlight")
    away_from_the_read()
    return True


ROWS = {"5": row_5, "6": row_6, "7": row_7, "8": row_8, "9": row_9,
        "15": row_15}


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(f"usage: {os.path.basename(__file__)} "
              f"{'|'.join(sorted(ROWS))}")
        missing = [r for r in ("5", "6", "7", "8", "9") if r not in ROWS]
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
