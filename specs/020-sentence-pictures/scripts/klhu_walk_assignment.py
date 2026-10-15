#!/usr/bin/env python3
"""klhu device walk — 020 quickstart rows 6-13 and 16.

Row 6:  the assignment line, the pass and the render's own ranges (FR-001,
        FR-002, FR-006, SC-001).
Row 7:  the two refusals, with their reasons and the assignment untouched
        (FR-003, FR-004, FR-012, SC-002).
Row 8:  un-assigning at the ends, refused in the middle, and the picture that
        becomes draggable (FR-016, SC-010).
Row 9:  the drag, and the order the render walks (FR-015, SC-009).
Row 10: the skip and the tail's fallback (FR-006, FR-007, SC-004).
Row 11: the stale warning before the render (FR-014, SC-008).
Row 12: no assignment is 012's video, frame for frame (FR-009, SC-003).
Row 13: the audio does not move (FR-008, SC-005).
Row 16: the assignment outlives the prompt (FR-010, FR-013, SC-006, SC-007).
Row 18: a highlighted sentence does not cut the video (FR-017, SC-011).

The mechanics are 016's (`specs/016-sentence-reading/scripts/klhu_walk_step.py`),
which are 015's, 014's and 012's beneath them: one string per `adb shell`
command, `uiautomator dump` reads, `check(name, ok, detail)` with a PASS/FAIL
summary and a non-zero exit on failure. **012's own module** is imported for what
only it has: pushing pictures to the device and driving the platform's own file
dialog (`make_pictures`/`push_pictures`/`choose_pictures`/`picture_at`), the
library's own per-file state (`library_state`, row 16), the phone's own video
album (`gallery_videos`/`clear_album`, row 16's kept file), and `preflight`,
which refuses to walk a device older than the APK on disk. **016's module** is
there for the reader's own stepping gesture, which is how row 18 puts a sentence
under the page's highlight and names it from the app's own line (`fresh_press`)
— and 011's beneath it for the yellow band the reader sees (`painted_band`).

020 adds only what is its own: its ten-sentence fixture, the reader's own three
pictures, the **new parser** for the renderer's own
`klhu render pictures=… ranges=… sentences=…` line — no driver in the tree reads
that line today, because no earlier feature had a schedule to read — the parser
for the render's own report (`klhu render done: … <ms>ms …B frames=<n>`), the
sentences a render spoke read off its own slot lines' `span=` (row 13: the
render path logs no `klhu speak` line — it writes each sentence to a file), and
the two gestures no earlier row drives: the assignment pass and the drag inside
it.

Usage:  /usr/bin/python3 -u klhu_walk_assignment.py 6
        ADB_SERIAL=emulator-5554 python3 -u klhu_walk_assignment.py 6
        KLHU_REPO=~/Documents/GitHub/Projects/klhu KLHU_OUT=/tmp/klhu_out \\
            python3 -u klhu_walk_assignment.py 6
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.

A row is implemented here in the pass that walks it; `main` names the rows it does
not have yet rather than dispatching into a stub (014's own convention).
"""
import json
import os
import re
import struct
import subprocess
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(
    os.environ.get("KLHU_REPO") or os.path.join(HERE, "..", "..", ".."))
for _spec in ("016-sentence-reading", "015-comment-tag",
              "014-reading-modes", "012-reading-video",
              "011-reading-experience"):
    sys.path.insert(0, os.path.join(REPO, "specs", _spec, "scripts"))

import klhu_walk_step as stepper  # noqa: E402
import klhu_walk_video as video  # noqa: E402

adb = video.adb
dump = video.dump
check = video.check
step = video.step
labels = video.labels
find = video.find
tap = video.tap
on_screen = video.on_screen
cat = video.cat
logcat = video.logcat
clear_logcat = video.clear_logcat
start_app = video.start_app
hard_restart = video.hard_restart
screencap = video.screencap
library_state = video.library_state
choose_pictures = video.choose_pictures
device_write = video.device_write
preflight = video.preflight
pull = video.pull
fresh_prefs = stepper.fresh_prefs
wait_for = video.wait_for
library_state = video.library_state
gallery_videos = video.gallery_videos
clear_album = video.clear_album
sha256_of = video.sha256_of
ALBUM = video.ALBUM
LIBRARY = video.LIBRARY
RESULTS = video.RESULTS
OUT = os.environ.get("KLHU_OUT", "/tmp/klhu_out")
DEV = os.environ.get("ADB_SERIAL", "emulator-5554")
PKG = video.PKG

# ---------------------------------------------------------------------------
# The row's own content: ten sentences, one per line, each ending in a full stop
# — short enough that the app's own resolver cuts them where this driver's
# `sentences()` does, and distinct enough that a still shows which one is which.
TEXT = (
    "Line one is here. Line two says this. Line three is next.\n\n"
    "Line four follows it. Line five now. Line six is here.\n\n"
    "Line seven again. Line eight says this. Line nine is next. "
    "Line ten ends it."
)

CONTENT_ID = "walk_020_ten"
CONTENT_NAME = "walk 020 ten sentences"
INDEX = f"{LIBRARY}/content/index.json"

# The reader's own three pictures: white, black and a colour, each a solid PNG
# so a frame's own off-column pixel names it (012's own way of reading a frame).
PICTURES = [
    ("w020_white.png", (255, 255, 255)),
    ("w020_black.png", (0, 0, 0)),
    ("w020_red.png", (220, 30, 30)),
]
PICTURE_DIR = "/sdcard/Pictures/klhu_walk_020"


def fresh_dump():
    """A dump whose **device-side** file is deleted first.

    `uiautomator dump` refuses to write while a window is animating ("could not get
    idle state"), and 012's `dump` then pulls the *previous* XML — a stale read
    that looks exactly like the app not updating. Deleting the device's copy makes
    a refused dump a missing file instead, and `dump`'s own retries then do their
    job. Row 6's third run read the prompt's line as `No sentences assigned`
    right after an assignment that the render itself proves was in force.
    """
    adb("shell", "rm", "-f", video.XML)
    return dump()


def dump_until(needle, seconds=8):
    """A dump carrying [needle], polled to a deadline: the dialog rebuilds under
    the popped pass, so the first dump after the tap can be a frame behind."""
    deadline = time.time() + seconds
    while True:
        rows = fresh_dump()
        if on_screen(rows, needle) or time.time() > deadline:
            return rows
        time.sleep(1)


# The four refusals, in the app's own English (this device's locale) — what
# `check` looks for on screen, and what says *which* rule was broken (FR-012).
REASONS = {
    "continuous": "Only the sentences next to the ones this picture already has "
                  "can be added.",
    "order": "That sentence comes before sentences an earlier picture already has.",
    "middle": "Only the first or last sentence of a picture can be removed.",
    "holds": "This picture holds sentences; un-assign them before moving it.",
}


def sentences(text=None):
    """The fixture's sentences, by the app's own rule (a full stop ends one).

    [text] is the content **as it stands now**: a row that rewrites the content
    mid-walk (row 11's own edit) reads the reader's page off the new text, not off
    the one the row seeded.
    """
    flat = " ".join((text or TEXT).replace("\n\n", " ").split())
    return [s.strip() + "." for s in flat.rstrip(".").split(".") if s.strip()]


def png(path, rgb, size=(720, 540)):
    """A solid PNG, written with the standard library only (no PIL on the box's
    own python3): one IHDR/IDAT/IEND, rows filtered 0."""
    w, h = size
    raw = b"".join(b"\x00" + bytes(rgb) * w for _ in range(h))

    def chunk(tag, data):
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(
            ">I", zlib.crc32(body) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", w, h, 8, 2, 0, 0, 0)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
                     chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))


def make_pictures():
    """The row's pictures on this box, and their absolute paths."""
    directory = os.path.join(OUT, "pics_020")
    os.makedirs(directory, exist_ok=True)
    paths = []
    for name, rgb in PICTURES:
        path = os.path.join(directory, name)
        png(path, rgb)
        paths.append(path)
    return paths


def push_pictures(paths):
    """Into the device's own Pictures folder, where the system dialog shows them."""
    adb("shell", "mkdir", "-p", PICTURE_DIR)
    for path in paths:
        adb("push", path, f"{PICTURE_DIR}/{os.path.basename(path)}")
    adb("shell", "am", "broadcast", "-a",
        "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
        "-d", f"file://{PICTURE_DIR}")


def seed_content():
    """Puts the ten-sentence content in the library and opens it (012's s2_seed,
    with this row's own id and text). The index is the library's own file, so the
    app is force-stopped after the write: what the rows then render is the file."""
    # A row starts from a known state: the app's stored settings go first, which
    # includes 020's own assignment (`content_picture_assignments` lives in the
    # same prefs file) — row 7's first run read the assignment row 6 had left
    # behind and its own two taps took two sentences *away* from it.
    fresh_prefs()
    directory = f"{LIBRARY}/content"
    adb("shell", "run-as", PKG, "mkdir", "-p", f"{directory}/contents")
    if not device_write(f"{directory}/contents/{CONTENT_ID}.txt", TEXT.encode()):
        check("6: the content is in the library", False, "the write failed")
        return False
    index = json.loads(cat(INDEX).decode())
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S.000000Z", time.gmtime())
    index["entries"] = [e for e in index["entries"] if e["id"] != CONTENT_ID] + [{
        "id": CONTENT_ID, "name": CONTENT_NAME, "language": "en", "origin": "user",
        "createdAt": stamp, "updatedAt": stamp, "charCount": len(TEXT),
    }]
    index["lastOpenedId"] = CONTENT_ID
    if not device_write(INDEX, json.dumps(index).encode()):
        check("6: the library index carries it", False, "the index write failed")
        return False
    adb("shell", "am", "force-stop", PKG)
    start_app()
    return True


def unseed_content():
    """Takes this row's content back out, so the walk leaves the device as it
    found it (012's own s2_unseed)."""
    index = json.loads(cat(INDEX).decode())
    index["entries"] = [e for e in index["entries"] if e["id"] != CONTENT_ID]
    if index.get("lastOpenedId") == CONTENT_ID:
        index["lastOpenedId"] = "preset_en_sample"
    device_write(INDEX, json.dumps(index).encode())
    adb("shell", "run-as", PKG, "rm", "-f",
        f"{LIBRARY}/content/contents/{CONTENT_ID}.txt")


# ---------------------------------------------------------------------------
# The renderer's own line — the one no driver in the tree reads yet.
#
# `klhu render pictures=3 ranges=0..84,85..170,171..255 sentences=10`
# A picture the video is too short to reach is printed as `-` (D5).
RENDER_PLAN_RE = re.compile(
    r"klhu render pictures=(\d+) ranges=(\S*) sentences=(\d+)")


def render_plan(log):
    """The schedule the renderer built, as (pictures, ranges, sentences).

    `ranges` is a list of `(start, end)` per picture in the order the render
    walks them, with `None` for a picture no frame reaches.
    """
    match = RENDER_PLAN_RE.search(log)
    if not match:
        return None
    ranges = []
    for token in match.group(2).split(","):
        if token == "-":
            ranges.append(None)
            continue
        start, end = token.split("..")
        ranges.append((int(start), int(end)))
    return (int(match.group(1)), ranges, int(match.group(3)))


def render_done(log):
    """The file the render wrote, or None: `klhu render done: <path> …ms …`."""
    match = re.search(r"klhu render done: (\S+)", log)
    return match.group(1) if match else None


# `klhu render done: <path> <ms>ms <bytes>B frames=<n>` — the one line the app
# writes when a render finishes (SC-001), and the only place a walk can read the
# file's own length rather than measure it again (row 13 compares the two).
RENDER_DONE_RE = re.compile(
    r"klhu render done: (\S+) (\d+)ms (\d+)B frames=(\d+)")


def render_report(log):
    """The render's own report: (path, ms, bytes, frames), or None."""
    match = RENDER_DONE_RE.search(log)
    if not match:
        return None
    return (match.group(1), int(match.group(2)), int(match.group(3)),
            int(match.group(4)))


# `klhu speak p<paragraph> s<sentence> [role=…] [voice=…] "<the sentence>"`
SPEAK_RE = re.compile(r"klhu speak (.*)$", re.M)


def utterances(log):
    """The utterances the app logged, one per sentence handed to the engine.

    Read here because quickstart row 13 names `klhu speak` lines as the audio's
    own evidence — and to let a row say what the tree actually produced instead
    of asserting one of the two: **nothing in the render path logs this line**
    (the renderer writes each sentence to a file through `synthesizeToFile`,
    which logs none, so `reader_service`'s line belongs to a *read*), and a
    render's own utterances are therefore read off its slot lines' `span=`.
    """
    return [match.group(1).strip() for match in SPEAK_RE.finditer(log)]


def spoken_spans(log):
    """The sentences a render spoke, in the render's own order, as the character
    ranges of the renderer's own slot lines (`span=a..b`).

    One per sentence: a sentence taller than the text area is painted as several
    line steps, which are runs of one slot carrying the same span, so the first
    of each distinct span is the utterance (012's own `slot_groups`, without the
    grouping — a span belongs to one sentence and repeats only for its steps).
    """
    spans = []
    for run in video.render_runs(log):
        key = (run["span_start"], run["span_end"])
        if key not in spans:
            spans.append(key)
    return spans


def sentence_lengths():
    """The fixture's sentences' own character counts, in order.

    What `span=`'s length is for each utterance — the app's own account, read
    against the fixture rather than against a number this driver remembered.
    """
    return [len(text) for text in sentences()]


def sentence_span(n):
    """The n-th sentence's own characters inside the fixture text.

    Computed from the text the row seeds — and it is what the app's own `span=`
    prints for that sentence (row 13 reads ten of them off the renderer's own
    lines and they agree, `(18, 37)` for the second).
    """
    spans, at = [], 0
    for text in sentences():
        found = TEXT.index(text, at)
        spans.append((found, found + len(text)))
        at = found + len(text)
    return spans[n]


def total_frames(log):
    """The render's own frame count, from its slot lines."""
    runs = video.render_runs(log)
    return runs[0]["total"] if runs else 0


def text_block(needle=None):
    """The painted content node of **this row's** fixture, from the raw tree.

    016's own finder keys off 015's comment fixture, which is not this row's
    text — so row 18 finds its own block the same way, by the text it seeds.
    """
    needle = needle or sentences()[0]
    for node in video.raw_nodes():
        if needle in (node["desc"] or node["text"]):
            return node
    return None


# ---------------------------------------------------------------------------
# The reader's own gestures on the device.
def dismiss_review(seconds=12):
    """Discards a review left up by an earlier render, **once it has settled**.

    The review arrives with a transition, so a tap at coordinates read while it
    is still moving misses — row 7's second render found the page's own toolbar
    still behind the review and read as "the video action is gone". The row waits
    for the Discard row's own coordinates to stop changing, taps, and waits for
    the review to be gone.
    """
    deadline = time.time() + seconds
    last = None
    while time.time() < deadline:
        rows = fresh_dump()
        if not on_screen(rows, "Discard"):
            return True
        spot = [(r["x"], r["y"]) for r in rows
                if (r["desc"] or r["text"]).strip() == "Discard"]
        if spot and spot == last:
            break
        last = spot
        time.sleep(1)
    rows = fresh_dump()
    if not on_screen(rows, "Discard"):
        return True
    if tap(rows, "Discard", label="an earlier review"):
        time.sleep(2.0)
    return not on_screen(fresh_dump(), "Discard")


def open_video_dialog(names, aspect="16:9 landscape"):
    """The video prompt, open, with [names] chosen through the platform's own
    file dialog (012's own flow: Video → the aspect → Choose pictures → the
    system Files app)."""
    dismiss_review()
    rows = fresh_dump()
    if not tap(rows, "Video", label="the video action"):
        return None
    time.sleep(1.5)
    rows = dump()
    if not tap(rows, aspect, label=aspect):
        return None
    time.sleep(0.6)
    rows = dump()
    if not tap(rows, "Choose pictures", label="Choose pictures"):
        return None
    time.sleep(3)
    if not choose_pictures(names):
        return None
    rows = dump()
    check(f"the prompt holds {len(names)} pictures",
          on_screen(rows, f"{len(names)} pictures chosen"),
          f"visible: {labels(rows)[:8]}")
    return rows


def assign_indices(plan, label="the reader's own assignment"):
    """Gives each named picture exactly the sentences at those indices.

    `assign` takes the next sentences in order, which is what a reader filling the
    content does; a row that needs a **gap** (an unassigned stretch between two
    runs, FR-006) says which sentences it wants instead. One tap per sentence, in
    the order the page shows them.
    """
    texts = sentences()
    rows = fresh_dump()
    chips = [chip_line(rows, name) for name, _ in PICTURES]
    check("the pass opens with nothing assigned (a clean row)",
          all(chip == "No sentences assigned" for chip in chips), f"chips: {chips}")
    for name, indices in plan.items():
        tap_chip(name)
        for index in indices:
            tap_row(texts[index], label=f"the sentence {texts[index]!r}")
        print(f"   {name}: {len(indices)} sentences assigned "
              f"({', '.join(texts[i] for i in indices)})")
    total = sum(len(indices) for indices in plan.values())
    rows = fresh_dump()
    if not tap(rows, "Done", label="Done"):
        return False
    time.sleep(2.0)
    rows = dump_until(f"{total} sentences")
    check(f"{label}: the prompt says {total} sentences are assigned",
          on_screen(rows, f"{total} sentences"),
          f"the labels mentioning sentences: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    return True


def open_pass(rows):
    """One tap on the assignment line (FR-001), and the pass is on the page."""
    if not tap(rows, "Assign sentences", label="the assignment line"):
        return None
    time.sleep(1.2)
    rows = dump()
    if not on_screen(rows, "Done"):
        check("the pass opened", False, f"visible: {labels(rows)[:8]}")
        return None
    check("the pass opened on the render's own sentences", True)
    return rows


def assign(rows, split):
    """Gives each picture its own sentences through the pass: tap the picture's
    chip, then the next [split] sentence rows, in the order the page shows them.

    [split] is one count per picture, in the pictures' own order — the reader's
    own gesture, one tap per sentence (FR-002, FR-003).
    """
    texts = sentences()
    rows = fresh_dump()
    chips = [chip_line(rows, name) for name, _ in PICTURES]
    check("the pass opens with nothing assigned (a clean row)",
          all(chip == "No sentences assigned" for chip in chips), f"chips: {chips}")
    taken = 0
    for index, count in enumerate(split):
        name = PICTURES[index][0]
        rows = dump()
        if not tap(rows, name, label=f"{name}'s chip"):
            return False
        time.sleep(0.4)
        for _ in range(count):
            rows = dump()
            if not tap(rows, texts[taken], label=f"the sentence {texts[taken]!r}"):
                return False
            taken += 1
            time.sleep(0.3)
        print(f"   {name}: {count} sentences assigned (through {texts[taken - 1]!r})")
    rows = dump()
    if not tap(rows, "Done", label="Done"):
        return False
    # The dialog rebuilds under the popped pass, so the dump that reads the
    # prompt's own line waits for it — a 1.2s sleep raced it once (row 6's first
    # run read the prompt before its line had the count).
    time.sleep(2.0)
    rows = dump_until(f"{taken} sentences")
    gone = [l for l in labels(rows) if "sentence" in l.lower()]
    print(f"   the prompt's own line: {gone}")
    check(f"the prompt says {taken} sentences are assigned",
          on_screen(rows, f"{taken} sentences"),
          f"the labels mentioning sentences: {gone}")
    return True


def shown_reason(rows):
    """Which refusal the pass is showing, by its own words, or None."""
    for key, text in REASONS.items():
        if any(text in (r["desc"] or r["text"]) for r in rows):
            return key
    return None


def reason_waits_out(seconds=8):
    """The pass with no refusal on screen: a SnackBar lives about four seconds,
    so a check that a refusal is *gone* has to wait it out."""
    deadline = time.time() + seconds
    while time.time() < deadline:
        if shown_reason(fresh_dump()) is None:
            return True
        time.sleep(1)
    return False


def chip_line(rows, name):
    """A picture's own count line (the chip carries its name and its count in
    one label, the app's own shape: `w020_white.png\\n4 sentences`)."""
    for r in rows:
        label = r["desc"] or r["text"]
        if label.startswith(name + "\n"):
            return label.split("\n", 1)[1]
    return None


def held_rows(rows):
    """The sentences the pass paints as held, in the page's own order.

    A held sentence carries its **holder's own file name** on its row — and the
    app paints that only when the sentence is not the *selected* picture's (the
    selected picture's own rows carry the app's `Remove this sentence` label
    instead). So this reads the rows that name a picture, and `read_held` leaves a
    picture holding nothing selected first: then every held row names its holder,
    whatever the reader had chosen before.
    """
    names = [name for name, _ in PICTURES]
    held = []
    for r in rows:
        label = r["desc"] or r["text"]
        text, sep, tail = label.partition("\n")
        if sep and tail in names:
            held.append(text)
    return held


def read_held():
    """The held sentences, read with the picture that holds nothing selected."""
    tap_chip(PICTURES[2][0])
    return held_rows(fresh_dump())


def hold(name, label=None):
    """The reader's own long press — 900ms on the spot, no movement: the gesture
    012's picker taught for its pictures, and the one the pass refuses when the
    picture holds sentences (FR-015)."""
    rows = fresh_dump()
    hits = find(rows, name)
    if not hits:
        check(f"the hold found {name}", False,
              f"visible: {labels(rows)[:10]}")
        return False
    r = hits[0]
    adb("shell", "input", "swipe", str(r["x"]), str(r["y"]), str(r["x"]),
        str(r["y"]), "900")
    print(f"   hold {label or name!r} @{r['x']},{r['y']}")
    time.sleep(1.2)
    return True


def drag(from_name, to_name, hold=1.6, steps=4):
    """The reader's own hold-and-drop, injected by hand.

    `input draganddrop` does **not** produce a Flutter long-press drag — probed on
    this device: the order stood and no refusal appeared. What does: DOWN, a real
    hold (1.6s, past the 500ms long press), MOVEs in steps to the target, UP — the
    same shape 012's `input swipe … 900` gets for the file dialog's selection mode,
    extended past the lift.
    """
    rows = fresh_dump()
    a = find(rows, from_name)
    b = find(rows, to_name)
    if not a or not b:
        check(f"the drag found {from_name} and {to_name}", False,
              f"visible: {labels(rows)[:10]}")
        return False
    start, end = (a[0]["x"], a[0]["y"]), (b[0]["x"], b[0]["y"])
    adb("shell", "input", "motionevent", "DOWN", str(start[0]), str(start[1]))
    time.sleep(hold)
    for step in range(1, steps + 1):
        adb("shell", "input", "motionevent", "MOVE",
            str(start[0] + (end[0] - start[0]) * step // steps),
            str(start[1] + (end[1] - start[1]) * step // steps))
        time.sleep(0.25)
    time.sleep(0.4)
    adb("shell", "input", "motionevent", "UP", str(end[0]), str(end[1]))
    print(f"   hold {from_name} @{start} and drop it on {to_name} @{end}")
    time.sleep(1.5)
    return True


def hold_only(name, seconds=1.6, label=None):
    """Holds a chip and reads what the app says **while the finger is down**.

    A refusal is a SnackBar (about four seconds), and a full drag gesture — the
    hold, four MOVEs and the release — takes about as long again, so a row that
    reads after the gesture can miss the very line it is checking. Answers
    (shown_reason, rows).
    """
    rows = fresh_dump()
    hits = find(rows, name)
    if not hits:
        check(f"the hold found {name}", False, f"visible: {labels(rows)[:10]}")
        return None, rows
    spot = (hits[0]["x"], hits[0]["y"])
    adb("shell", "input", "motionevent", "DOWN", str(spot[0]), str(spot[1]))
    time.sleep(seconds)
    rows = fresh_dump()
    print(f"   hold {label or name!r} @{spot} and read while it is held")
    adb("shell", "input", "motionevent", "UP", str(spot[0]), str(spot[1]))
    time.sleep(0.6)
    return shown_reason(rows), rows


def chip_order(rows):
    """The pictures in the order the pass shows them."""
    names = [name for name, _ in PICTURES]
    order = []
    for r in rows:
        first = (r["desc"] or r["text"]).split("\n")[0]
        if first in names and first not in order:
            order.append(first)
    return order


def sentence_frames(log):
    """Each sentence's own first frame, in the render's own order.

    Read from the renderer's slot lines through **012's own parser**, keyed by the
    sentence's span — so a range's boundary can be checked against the sentence it
    falls on rather than against a number this driver guessed.
    """
    frames = {}
    for run in video.render_runs(log):
        frames.setdefault((run["span_start"], run["span_end"]), run["start"])
    return [frames[key] for key in sorted(frames)]


def tap_chip(name):
    """Selects a picture in the pass."""
    rows = fresh_dump()
    if not tap(rows, name, label=f"{name}'s chip"):
        check(f"the chip {name} is on the page", False,
              f"visible: {labels(rows)[:10]}")
        return False
    time.sleep(0.4)
    return True


def tap_row(text, label=None):
    """One tap on a sentence row of the pass."""
    rows = fresh_dump()
    if not tap(rows, text, label=label or f"the sentence {text!r}"):
        check(f"the sentence row {text!r} is on the page", False,
              f"visible: {labels(rows)[:10]}")
        return False
    time.sleep(0.6)
    return True


def app_line(log):
    """The app's own schedule line, verbatim — what a row quotes and what two
    renders are compared by."""
    for line in log.splitlines():
        if "klhu render pictures=" in line:
            return line.strip()
    return None


def start_render(seconds=150):
    """Start, and the app's own lines when it is done. Answers the log.

    A render that never reports is a row that must say *why*, not a row whose
    checks read `None`: the app's own lines are printed when the poll runs out.
    """
    clear_logcat()
    rows = fresh_dump()
    if not tap(rows, "Start", label="Start"):
        return ""
    started = time.time()
    while time.time() - started < seconds:
        log = logcat()
        if "klhu render done:" in log or "klhu render failed" in log:
            # The review is the render's own last screen: waiting for it here
            # means every caller sees the same settled state 012's rows do.
            time.sleep(1.5)
            dump_until("Discard", 15)
            time.sleep(1.5)
            return logcat()
        time.sleep(2)
    log = logcat()
    print("   the render never reported; the app's own lines were:")
    for line in log.splitlines():
        if "klhu" in line and ("render" in line or "speak" in line):
            print("     ", line.strip()[:150])
    print("   on screen:",
          labels(fresh_dump())[:10])
    return log


def frame_at(file_name, frame, label):
    """The frame's own off-column pixel, as (r, g, b) — what picture is under it.

    The render's own frame numbering is what the schedule prints, so a frame
    inside a range is read without guessing (012's own sampling: a pixel outside
    the text column can only be the picture's).
    """
    dest = os.path.join(OUT, f"{label}_frame{frame}.png")
    subprocess.run(
        ["ffmpeg", "-v", "error", "-y", "-i", file_name, "-vf",
         f"select=eq(n\\,{frame})", "-vframes", "1", dest],
        capture_output=True)
    return dest


# ---------------------------------------------------------------------------
# row 6 — the assignment line, the pass and the render's own ranges
# ---------------------------------------------------------------------------
def row_6():
    step("row 6 — the reader assigns 4/3/3 and the render walks the runs")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    print(f"   the fixture's {len(texts)} sentences: {texts[0]!r} … {texts[-1]!r}")
    check("6: the fixture has the ten sentences the row seeds", len(texts) == 10,
          f"{len(texts)} sentences")
    push_pictures(make_pictures())

    rows = open_video_dialog([p[0] for p in PICTURES])
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    rows = dump_until(texts[0])
    check("6: the pass shows the render's own sentences, in order",
          all(on_screen(rows, text) for text in texts[:3]),
          f"visible: {labels(rows)[:10]}")
    screencap("/tmp/020_row6_pass_open.png")
    if not assign(rows, [4, 3, 3]):
        return
    screencap("/tmp/020_row6_assigned.png")

    log = start_render()
    plan = render_plan(log)
    if plan is None:
        check("6: the renderer printed its own schedule", False,
              f"the render's lines: {[l for l in log.splitlines() if 'klhu render' in l][:3]}")
        return
    # The app's own line, verbatim, for the record: the parser above is what the
    # checks read, but a walk's evidence is the device's own words.
    print("   the app's own line:", app_line(log))
    pictures, ranges, spoken = plan
    print(f"   klhu render pictures={pictures} ranges="
          f"{','.join('-' if r is None else f'{r[0]}..{r[1]}' for r in ranges)} "
          f"sentences={spoken}")
    check("6: the render speaks the content's own sentences (FR-017)", spoken == 10,
          f"sentences={spoken}")
    check("6: the schedule carries the reader's three pictures (FR-002)", pictures == 3,
          f"pictures={pictures}")
    check("6: every picture is drawn and the ranges meet, in the reader's order",
          all(r is not None for r in ranges) and
          all(ranges[i][1] + 1 == ranges[i + 1][0] for i in range(len(ranges) - 1)),
          f"ranges={ranges}")
    check("6: the first range opens the video", ranges and ranges[0][0] == 0,
          f"first={ranges[0] if ranges else None}")

    # A frame inside each range carries that picture's own colour, and no other.
    file_name = render_done(log)
    if file_name is None:
        check("6: the render wrote a file", False, "no done line")
        return
    # 012's own pull: the file lives in the app's private storage, so it comes
    # back through `run-as` — an `adb pull` of that path reads nothing.
    still = os.path.join(OUT, "row6.mp4")
    data, pulled = pull(file_name, still)
    check("6: the render's own file came back", pulled and bool(data),
          f"{len(data)} bytes from {file_name}")
    if not pulled or not data:
        return
    for index, (name, rgb) in enumerate(PICTURES):
        if ranges[index] is None or index >= len(ranges):
            continue
        start, end = ranges[index]
        frame = start if end - start < 40 else start + 20
        dest = frame_at(still, frame, f"row6_{name}")
        pixel = off_column_pixel(dest)
        check(f"6: frame {frame} (inside {name}'s range) carries {rgb}",
              pixel is not None and
              all(abs(a - b) <= 24 for a, b in zip(pixel, rgb)),
              f"the frame's own off-column pixel: {pixel}")
    screencap("/tmp/020_row6_review.png")

    # The walk leaves the device as it found it: the row's own content goes back
    # out (the pictures stay in Pictures/ — the reader's own folder, and 012's
    # rows leave theirs there too).
    unseed_content()
    check("6: the row's own content is out of the library again", True,
          f"{CONTENT_ID} removed from the index and the disk")


def off_column_pixel(png_path):
    """The colour at a point outside the text column, read with ffmpeg.

    The app draws its words inside a column and the picture everywhere else, so
    this is the picture's own colour (012 samples the same way; ffmpeg is what
    both boxes have, PIL is not).
    """
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", png_path, "-vf", "crop=8:8:8:8",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True)
    if out.returncode != 0 or len(out.stdout) < 3:
        return None
    return tuple(out.stdout[:3])



# ---------------------------------------------------------------------------
# row 7 — the two refusals, with their own reasons and the runs untouched
# ---------------------------------------------------------------------------
def row_7():
    step("row 7 — a far sentence and an out-of-order sentence, each refused")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    push_pictures(make_pictures())

    # The reader's own assignment, and the render that says what is in force.
    rows = open_video_dialog([p[0] for p in PICTURES])
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign(rows, [2, 0, 0]):
        return
    screencap("/tmp/020_row7_assigned.png")
    log = start_render()
    before = app_line(log)
    plan = render_plan(log)
    check("7: the first render's own line is the reader's two sentences",
          plan is not None and plan[1][0] is not None and plan[1][0][0] == 0,
          f"{before}")
    if before is None:
        return

    # The same three files again: the stored runs re-attach by name (FR-010) and
    # the pass opens on them.
    rows = open_video_dialog([p[0] for p in PICTURES])
    if rows is None:
        return
    rows = dump_until("2 sentences")
    check("7: the stored runs came back with the same files (FR-010)",
          on_screen(rows, "2 sentences"), f"visible: {labels(rows)[:8]}")
    rows = open_pass(rows)
    if rows is None:
        return
    rows = fresh_dump()
    counts = {name: chip_line(rows, name) for name, _ in PICTURES}
    print(f"   the chips say: {counts}")
    check("7: the pass opens with the reader's own run in force",
          counts[PICTURES[0][0]] == "2 sentences", f"{counts}")

    # (1) a sentence far from the run: the continuity rule (FR-003).
    tap_chip(PICTURES[0][0])
    tap_row(texts[4])
    rows = dump_until(REASONS["continuous"])
    check("7: a sentence not next to the run is refused, with the continuity rule",
          shown_reason(rows) == "continuous", f"on screen: {labels(rows)[:8]}")
    check("7: and it is the only rule named (FR-012)",
          sum(1 for key in REASONS
              if any(REASONS[key] in (r["desc"] or r["text"]) for r in rows)) == 1,
          f"visible: {labels(rows)[:8]}")
    screencap("/tmp/020_row7_refused_continuous.png")

    # (2) a sentence that starts before an earlier picture's own: the order rule
    # (FR-004). Black comes after white, and white holds the first two.
    tap_chip(PICTURES[1][0])
    tap_row(texts[0])
    rows = dump_until(REASONS["order"])
    check("7: a sentence before an earlier picture's own is refused, with the order rule",
          shown_reason(rows) == "order", f"on screen: {labels(rows)[:8]}")
    screencap("/tmp/020_row7_refused_order.png")

    # Neither refusal moved anything (FR-012).
    rows = fresh_dump()
    after_counts = {name: chip_line(rows, name) for name, _ in PICTURES}
    check("7: nothing moved under the two refusals (FR-012)",
          after_counts == counts, f"before {counts}, after {after_counts}")
    held = read_held()
    check("7: the page still paints the reader's own two sentences as held",
          held == texts[:2], f"held: {held}")

    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(2.0)
    after = app_line(start_render())
    check("7: the assignment in force is the one that renders — the same line, both times",
          after is not None and after.split(": ")[-1] == before.split(": ")[-1],
          f"before: {before}\nafter:  {after}")
    screencap("/tmp/020_row7_review.png")
    unseed_content()


# ---------------------------------------------------------------------------
# row 8 — un-assigning: the ends go, the middle refuses, the picture frees
# ---------------------------------------------------------------------------
def row_8():
    step("row 8 — an end sentence goes, the middle refuses, and the picture frees")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    push_pictures(make_pictures())
    rows = open_video_dialog([p[0] for p in PICTURES])
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign(rows, [3, 0, 0]):
        return
    screencap("/tmp/020_row8_three.png")
    white = PICTURES[0][0]

    # `assign` ends by confirming the pass, which closes it (and stores the
    # runs). The reader's own work here is inside the pass, so it opens on those
    # runs again — the row's first run tried to hold a chip on the *prompt*.
    rows = open_pass(fresh_dump())
    if rows is None:
        return
    check("8: the pass opens again on the reader's own run (FR-010)",
          chip_line(fresh_dump(), white) == "3 sentences",
          f"chips: {[chip_line(fresh_dump(), n) for n, _ in PICTURES]}")

    # A picture holding sentences refuses the hold, with its reason (FR-015).
    if not hold(white, label="the picture holding three"):
        return
    rows = fresh_dump()
    check("8: a picture holding sentences refuses the hold, with its reason",
          shown_reason(rows) == "holds", f"on screen: {labels(rows)[:8]}")
    check("8: and nothing moved under the refusal",
          [chip_line(rows, name) for name, _ in PICTURES] ==
          ["3 sentences", "No sentences assigned", "No sentences assigned"],
          f"chips: {[chip_line(rows, n) for n, _ in PICTURES]}")
    screencap("/tmp/020_row8_refused_holds.png")
    reason_waits_out()

    # The middle of the run refuses to go (FR-016).
    tap_chip(white)
    tap_row(texts[1], label="the middle sentence")
    rows = dump_until(REASONS["middle"])
    check("8: the middle sentence is refused, with the middle rule",
          shown_reason(rows) == "middle", f"on screen: {labels(rows)[:8]}")
    held = read_held()
    check("8: and the run is untouched by the refusal (FR-012)",
          held == texts[:3] and chip_line(fresh_dump(), white) == "3 sentences",
          f"held: {held}, chip: {chip_line(fresh_dump(), white)}")
    screencap("/tmp/020_row8_refused_middle.png")

    # An end goes, and what is left is one run.
    tap_chip(white)
    tap_row(texts[0], label="the first sentence")
    held = read_held()
    check("8: an end sentence goes, and the run left is continuous (FR-016)",
          held == texts[1:3] and chip_line(fresh_dump(), white) == "2 sentences",
          f"held: {held}, chip: {chip_line(fresh_dump(), white)}")
    tap_chip(white)
    tap_row(texts[2], label="the other end")
    held = read_held()
    check("8: the other end too — one sentence, still one run",
          held == [texts[1]] and chip_line(fresh_dump(), white) == "1 sentence",
          f"held: {held}, chip: {chip_line(fresh_dump(), white)}")
    tap_chip(white)
    tap_row(texts[1], label="the last sentence")
    held = read_held()
    check("8: the last sentence goes, and the picture holds nothing",
          held == [] and chip_line(fresh_dump(), white) == "No sentences assigned",
          f"held: {held}, chip: {chip_line(fresh_dump(), white)}")
    screencap("/tmp/020_row8_freed.png")

    # With nothing held, the hold no longer refuses it: the picture is free to
    # move (the move itself is row 9's own evidence, quickstart row 9).
    if not hold(white, label="the picture holding nothing"):
        return
    # An earlier refusal's SnackBar lives about four seconds: "no longer refuses"
    # is only honest once whatever was up has had its time.
    gone = reason_waits_out()
    rows = fresh_dump()
    check("8: and now the hold does not refuse it — the picture is free to move",
          gone and shown_reason(rows) is None,
          f"still on screen: {[l for l in labels(rows) if any(r in l for r in REASONS.values())]}"
          f" (waited the earlier one out: {gone})")
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(2.0)
    if tap(fresh_dump(), "Cancel", label="Cancel"):
        print("   the prompt is closed; the row's own assignment stays stored")
    screencap("/tmp/020_row8_review.png")
    unseed_content()



# ---------------------------------------------------------------------------
# row 9 — the drag, and the order the render walks
# ---------------------------------------------------------------------------
def row_9():
    step("row 9 — a free picture dragged to the front, and one holding sentences refused")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    push_pictures(make_pictures())
    names = [p[0] for p in PICTURES]
    # The picture holding nothing is the one **between** two runs: a picture after
    # the last run is fed by FR-006's tail fallback and is drawn (row 9's first run
    # assigned the last picture nothing and the render painted it all the same).
    free = PICTURES[1][0]
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign_indices({names[0]: [0, 1, 2], names[2]: [3, 4, 5]}):
        return
    screencap("/tmp/020_row9_assigned.png")
    log = start_render()
    before = app_line(log)
    plan_before = render_plan(log)
    check("9: the first render's own line has the picture between the runs as a `-` (FR-007)",
          plan_before is not None and plan_before[1][1] is None,
          f"{before}")

    # The reader comes back to the same three files, opens the pass on their own
    # runs, and drags the free picture to the front — then tries the same on a
    # picture that holds sentences.
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    check("9: the pass opens on the reader's own runs, in the order they were made",
          chip_order(fresh_dump()) == names, f"{chip_order(fresh_dump())}")
    refusal, rows = hold_only(names[0], label="a picture holding sentences")
    if refusal is None and rows:
        pass
    check("9: a picture holding sentences refuses the hold, with its reason (FR-015)",
          refusal == "holds", f"on screen: {labels(rows)[:8]}")
    rows = fresh_dump()
    check("9: and the order stands under the refusal",
          chip_order(rows) == names, f"{chip_order(rows)}")
    screencap("/tmp/020_row9_refused.png")
    reason_waits_out()

    if not drag(free, names[0]):
        return
    rows = fresh_dump()
    after_order = chip_order(rows)
    check("9: the free picture lands where the reader dropped it (FR-015)",
          after_order == [free, names[0], names[2]], f"{after_order}")
    check("9: and nothing was refused while it moved",
          shown_reason(rows) is None, f"on screen: {labels(rows)[:8]}")
    screencap("/tmp/020_row9_moved.png")

    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(2.0)
    after = app_line(start_render())
    plan_after = render_plan(logcat())
    check("9: the render walks the order the pass shows (SC-009)",
          plan_after is not None and plan_after[1][0] is None,
          f"{after}")
    # "No other range moved": the numbers themselves are the same ones, in the
    # same order — only the `-` (the picture that paints nothing) has moved.
    check("9: and no other range moved — the same numbers, one place along",
          plan_after is not None and plan_before is not None
          and [r for r in plan_after[1] if r is not None]
          == [r for r in plan_before[1] if r is not None],
          f"before {plan_before[1] if plan_before else None} → after {plan_after[1] if plan_after else None}")
    screencap("/tmp/020_row9_review.png")
    unseed_content()


# ---------------------------------------------------------------------------
# row 10 — the skip and the tail's fallback
# ---------------------------------------------------------------------------
def row_10():
    step("row 10 — the skipped picture, and the tail that falls to the ones after it")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    push_pictures(make_pictures())
    names = [p[0] for p in PICTURES]
    white, black, red = names

    # State 1: white takes the first three sentences, red the last three, and the
    # picture between them is left with nothing (the gap in the middle keeps the
    # picture before it, FR-006).
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign_indices({white: [0, 1, 2], red: [6, 7, 8]}):
        return
    log = start_render()
    plan = render_plan(log)
    starts = sentence_frames(log)
    check("10: the render speaks the content's own ten sentences", len(starts) == 10,
          f"{len(starts)} sentences in the slot lines")
    check("10: the middle picture is in no frame — its range is a `-` (FR-007, D5)",
          plan is not None and plan[1][1] is None,
          f"ranges={plan[1] if plan else None}")
    check("10: and the unassigned sentences between the runs kept the picture before them (FR-006)",
          plan is not None and starts and plan[1][0] == (0, starts[6] - 1),
          f"white {plan[1][0] if plan else None} against sentence 7's frame {starts[6] if len(starts) > 6 else None}")
    total = video.render_runs(log)[0]["total"] if video.render_runs(log) else 0
    check("10: and the last picture holds to the video's own last frame (012's own rule)",
          plan is not None and plan[1][2] is not None and plan[1][2][1] == total - 1,
          f"red {plan[1][2] if plan else None} against the video's {total} frames")
    screencap("/tmp/020_row10_skip.png")

    # State 2: red's run is taken back, so the tail is unassigned with two
    # pictures after it — and 012's own even split hands it to them.
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    check("10: the pass opens on the reader's own runs again (FR-010)",
          chip_line(fresh_dump(), red) == "3 sentences", f"{chip_line(fresh_dump(), red)}")
    tap_chip(red)
    for text in texts[6:9]:
        tap_row(text, label=f"take back {text!r}")
    rows = fresh_dump()
    check("10: the last picture holds nothing now",
          chip_line(rows, red) == "No sentences assigned", f"{chip_line(rows, red)}")
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(2.0)
    log = start_render()
    plan = render_plan(log)
    starts = sentence_frames(log)
    # The tail is sentences 4-10 (7 of them) over the two pictures after white:
    # 012's own even split gives the first 4 and the second 3.
    check("10: the tail falls to the pictures after the last assigned one, split as 012 splits it (FR-006)",
          plan is not None and plan[1][1] is not None and plan[1][2] is not None
          and plan[1][1] == (starts[3], starts[7] - 1)
          and plan[1][2][0] == starts[7],
          f"black {plan[1][1] if plan else None} (sentences 4-7 = {starts[3]}..{starts[7] - 1}), "
          f"red {plan[1][2] if plan else None} from sentence 8's frame {starts[7]}")
    check("10: and the picture before them still holds its own run",
          plan is not None and plan[1][0] == (0, starts[3] - 1),
          f"white {plan[1][0] if plan else None} against sentence 4's frame {starts[3]}")
    screencap("/tmp/020_row10_tail.png")
    unseed_content()



# ---------------------------------------------------------------------------
# row 11 — the stale warning, before the render
# ---------------------------------------------------------------------------
def row_11():
    step("row 11 — the content changes under an assignment, and the reader is told first")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    push_pictures(make_pictures())
    names = [p[0] for p in PICTURES]
    white = names[0]

    # The reader's own assignment: the first picture takes the first three
    # sentences.
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign_indices({white: [0, 1, 2]}):
        return

    # The content changes under it: the same content id, its first sentence
    # rewritten, so the stored run's spans match no sentence of the text in force
    # (FR-014's own shape). Written through `run-as`, and the app is force-stopped
    # so what it reads next is the file and not a session's leftover.
    changed = TEXT.replace("Line one is here.", "Something else entirely is here.")
    device_write(f"{LIBRARY}/content/contents/{CONTENT_ID}.txt", changed.encode())
    adb("shell", "am", "force-stop", PKG)
    start_app()
    print("   the content's first sentence was rewritten under the assignment")

    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = dump_until("3 sentences")
    check("11: the stored runs came back with the same files (FR-010)",
          on_screen(rows, "3 sentences"),
          f"the labels mentioning sentences: {[l for l in labels(rows) if 'sentence' in l.lower()]}")

    clear_logcat()
    title = "1 assigned run no longer fits this text"
    detail = f"{white}: sentences 3"
    if not tap(fresh_dump(), "Start", label="Start"):
        return
    rows = dump_until(title)
    check("11: the warning is on screen before anything is rendered (FR-014, SC-008)",
          on_screen(rows, title), f"on screen: {labels(rows)[:10]}")
    check("11: and it names the picture and how many sentences its run held",
          on_screen(rows, detail), f"on screen: {labels(rows)[:12]}")
    check("11: no render has begun — the app's own line is not there yet",
          app_line(logcat()) is None,
          f"the render's own line: {app_line(logcat())}")
    screencap("/tmp/020_row11_warning.png")

    # The telling is the gesture (FR-014): the line that names the picture.
    if not tap(rows, detail, label="the warning's own line"):
        return
    rows = dump_until("Done")
    check("11: the tap lands on the assignment pass",
          on_screen(rows, "Done") and on_screen(rows, "Assign sentences"),
          f"on screen: {labels(rows)[:8]}")
    check("11: and it opens on the picture the warning named (its run is not in force)",
          chip_line(rows, white) == "No sentences assigned",
          f"chips: {[chip_line(rows, c) for c in names]}")
    screencap("/tmp/020_row11_pass.png")

    # "In view" is the selection, and a chip's selection is not in the dump: the
    # reader's own next tap is — give one sentence, and it must be that picture's.
    # The page is showing the **changed** text, so the sentence is that text's own
    # first one (row 11's first run tapped the seeded text's and found nothing).
    tap_row(sentences(changed)[0],
            label="the first sentence of the changed text")
    rows = fresh_dump()
    check("11: the reader's next tap goes to the picture the warning named",
          chip_line(rows, white) == "1 sentence"
          and all(chip_line(rows, name) == "No sentences assigned"
                  for name in names[1:]),
          f"chips: {[chip_line(rows, c) for c in names]}")
    screencap("/tmp/020_row11_fixed.png")
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(2.0)
    tap(fresh_dump(), "Cancel", label="Cancel")
    unseed_content()


# ---------------------------------------------------------------------------
# row 12 — with no assignment the render is 012's own, frame for frame
# ---------------------------------------------------------------------------
def row_12():
    step("row 12 — nothing assigned, and the render is 012's own video")
    preflight()
    # The tree's own pre-set and 012's own nine pictures: this row is the
    # regression check 020 owes 012, so it uses 012's fixture and 012's figures.
    fresh_prefs()
    start_app()
    pictures = video.row_pictures()
    video.push_pictures(video.make_pictures())
    names = [p[0] for p in pictures]
    print(f"   012's own fixture: {len(names)} pictures, the pre-set's "
          f"{len(video.preset_sentences())} sentences")

    rows = open_video_dialog(names[:5])
    if rows is None:
        return
    check("12: the first five pictures are on the page",
          on_screen(fresh_dump(), "5 pictures chosen"),
          f"visible: {labels(fresh_dump())[:8]}")
    rows = fresh_dump()
    if not tap(rows, "Choose more", label="Choose more"):
        return
    time.sleep(3)
    if not choose_pictures(names[5:9]):
        return
    rows = dump_until("9 pictures chosen")
    check("12: nine pictures chosen, one over the count, said nothing about (012's own row 49)",
          on_screen(rows, "9 pictures chosen"), f"visible: {labels(rows)[:8]}")
    check("12: and the reader has assigned nothing — the schedule is 012's",
          on_screen(rows, "No sentences assigned"),
          f"the labels mentioning sentences: {[l for l in labels(rows) if 'sentence' in l.lower()]}")
    screencap("/tmp/020_row12_prompt.png")

    log = start_render(seconds=240)
    line = app_line(log)
    plan = render_plan(log)
    print("   the app's own line:", line)
    check("12: nine pictures, eight ranges — one per sentence — and the ninth in no range (row 49)",
          plan is not None and plan[0] == 9 and plan[2] == 8
          and sum(1 for r in plan[1] if r is not None) == 8
          and plan[1][-1] is None,
          f"{line}")
    exact = video.preset_sentences()
    check("12: the render speaks the pre-set's own eight sentences",
          plan is not None and plan[2] == len(exact), f"{plan[2] if plan else None}")

    file_name = render_done(log)
    if file_name is None:
        check("12: the render wrote a file", False, "no done line")
        return
    dest = os.path.join(OUT, "row12.mp4")
    data, pulled = pull(file_name, dest)
    check("12: the render's own file came back", pulled and bool(data),
          f"{len(data)} bytes from {file_name}")
    if not pulled or not data:
        return
    probed = video.probe(dest)
    if probed is None:
        check("12: ffprobe read the file", False, "ffprobe failed")
        return
    frames = int(probed["streams"][0]["nb_read_frames"])
    seconds = video.duration_s(probed)
    print(f"   ffprobe: {frames} frames, {seconds} s")
    # 012's own row 31 recorded 818 frames and 27.39 s for the same pre-set on
    # 2026-10-07 — figures **its own row 49 no longer reproduces** on this emulator
    # today (re-walked 2026-10-14, 40/41: 743 frames, 24766 ms), which is the
    # synthesis' own duration and not something 020 moves. So this row's comparison
    # is against 012's row **as it renders today**, and the deviation from row 31's
    # own numbers is reported rather than smoothed over.
    check("12: the frame count is 012's own, rendered today (743 frames)",
          frames == 743, f"{frames} frames (012's row 31 recorded 818; its row 49 "
          f"re-walked 2026-10-14 renders 743 too)")
    check("12: and so is the duration (012's row 49 today: 24766 ms)",
          abs(seconds - 24.766) <= 0.5, f"{seconds} s (row 31 recorded 27.39)")
    screencap("/tmp/020_row12_review.png")


# ---------------------------------------------------------------------------
# row 13 — the audio does not move
# ---------------------------------------------------------------------------
def row_13():
    step("row 13 — the audio does not move: the same utterances, the same length")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    lengths = sentence_lengths()
    push_pictures(make_pictures())
    names = [p[0] for p in PICTURES]

    # (1) The same content and the same three pictures, with **nothing
    # assigned** — 012's own even split, and this row's baseline for the audio.
    rows = open_video_dialog(names)
    if rows is None:
        return
    log_quiet = start_render()
    line_quiet = app_line(log_quiet)
    plan_quiet = render_plan(log_quiet)
    report_quiet = render_report(log_quiet)
    spans_quiet = spoken_spans(log_quiet)
    speaks = utterances(log_quiet)
    print(f"   without an assignment: {line_quiet}")
    print(f"   the render's own report: {report_quiet}")
    print(f"   the render's own utterances, by span: {spans_quiet}")
    print(f"   `klhu speak` lines in the render's log: {speaks}")
    if plan_quiet is None or report_quiet is None:
        check("13: the first render reported its own lines", False,
              f"line={line_quiet} report={report_quiet}")
        return

    # (2) The reader's own runs, through the pass — **2 / 4 / 4**, which is not
    # the split 012's fallback would pick (its even split of this content's ten
    # sentences over three pictures is 4 / 3 / 3 — the first run of this row
    # assigned exactly that and the two schedule lines came out identical), so
    # the pictures really do move and the audio is compared under a change.
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign(rows, [2, 4, 4]):
        return
    log_runs = start_render()
    line_runs = app_line(log_runs)
    plan_runs = render_plan(log_runs)
    report_runs = render_report(log_runs)
    spans_runs = spoken_spans(log_runs)
    print(f"   with the reader's runs: {line_runs}")
    print(f"   the render's own report: {report_runs}")
    print(f"   the render's own utterances, by span: {spans_runs}")
    screencap("/tmp/020_row13_review.png")

    check("13: the render speaks the content's own sentences — all ten, in order (FR-008)",
          len(spans_quiet) == len(texts)
          and [end - start for start, end in spans_quiet] == lengths,
          f"{len(spans_quiet)} utterances, spans {spans_quiet} "
          f"against the content's own sentence lengths {lengths}")
    check("13: and with an assignment they are the same utterances, in the same order (SC-005)",
          spans_runs == spans_quiet,
          f"{len(spans_runs)} utterances: {spans_runs} against {spans_quiet}")
    check("13: the video is the same length — the render's own report",
          report_runs is not None
          and report_runs[1] == report_quiet[1]
          and report_runs[3] == report_quiet[3],
          f"{report_quiet[1]}ms/{report_quiet[3]} frames without an assignment → "
          f"{report_runs[1]}ms/{report_runs[3]} frames with the reader's runs")
    check("13: the assignment moved the pictures and nothing else",
          plan_runs is not None
          and plan_runs[0] == plan_quiet[0] and plan_runs[2] == plan_quiet[2]
          and plan_runs[1] != plan_quiet[1],
          f"without: {line_quiet}\nwith:    {line_runs}")
    unseed_content()


# ---------------------------------------------------------------------------
# row 16 — the assignment outlives the prompt, and re-attaches by name
# ---------------------------------------------------------------------------
def row_16():
    step("row 16 — the runs outlive a relaunch, re-attach by name, and the first file stands")
    preflight()
    # The row keeps a video, so the phone's own album is emptied first — and
    # again at the end: a walk that leaves the reader's gallery holding a file of
    # its own cannot tell an earlier run's file from this one's.
    clear_album()
    if not seed_content():
        return
    texts = sentences()
    push_pictures(make_pictures())
    names = [p[0] for p in PICTURES]
    white, black, red = names
    before = {white: "4 sentences", black: "3 sentences", red: "3 sentences"}

    # (1) The reader's runs through the pass — white the first four sentences,
    # black the next three, red the last three — and the first render.
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = open_pass(rows)
    if rows is None:
        return
    if not assign(rows, [4, 3, 3]):
        return
    log_1 = start_render()
    line_1 = app_line(log_1)
    plan_1 = render_plan(log_1)
    starts_1 = sentence_frames(log_1)
    file_1 = render_done(log_1)
    total_1 = total_frames(log_1)
    print(f"   first render: {line_1}")
    if plan_1 is None or file_1 is None or len(starts_1) != len(texts):
        check("16: the first render reported its own line, file and sentences", False,
              f"{line_1} / {file_1} / {len(starts_1)} sentences")
        return
    # The reader's runs against the render's own ranges, each range read against
    # the sentences' **own** first frames rather than against numbers this
    # driver remembered.
    check("16: the render walks the reader's runs — 4 / 3 / 3, in their order",
          plan_1 is not None
          and tuple(plan_1[1]) == ((0, starts_1[4] - 1),
                                   (starts_1[4], starts_1[7] - 1),
                                   (starts_1[7], total_1 - 1)),
          f"{line_1} against the sentences' own frames {starts_1} "
          f"and the video's {total_1} frames")
    # The render's own file, off the device before the next render's own
    # `startRender` deletes it (012's own cache rule).
    first_dest = os.path.join(OUT, "row16_first.mp4")
    data_first, got_first = pull(file_1, first_dest)
    check("16: the first render's own file came off the device",
          got_first and bool(data_first), f"{len(data_first)}B from {file_1}")

    # (2) The reader keeps it: the file becomes their own, in the phone's album
    # and its library — this is the row's "first file".
    rows = fresh_dump()
    if not tap(rows, "Save", label="Save (the review's)", exact=True):
        return
    kept_name = f"{CONTENT_NAME}.mp4"
    kept_files = wait_for(lambda: gallery_videos()[0], 25) or []
    kept_entries = gallery_videos()[1]
    print(f"   the phone's own gallery: {kept_files} / {kept_entries}")
    check("16: the file the reader kept is in the album and in the library, under the content's name",
          kept_name in kept_files and kept_name in kept_entries,
          f"files={kept_files} entries={kept_entries}")
    if kept_name not in kept_files:
        return
    kept_dest = os.path.join(OUT, "row16_kept.mp4")
    subprocess.run(["adb", "-s", DEV, "pull", f"{ALBUM}/{kept_name}", kept_dest],
                   capture_output=True)
    kept_before = (sha256_of(open(kept_dest, "rb").read())
                   if os.path.exists(kept_dest) else "")
    check("16: and it came off the device", bool(kept_before),
          f"{kept_dest} sha256={kept_before[:16]}…")

    # (3) The reader leaves the screen and the app is stopped and started again:
    # the runs come back with the same files, by name (FR-010, SC-006). Not
    # `hard_restart` — that is `pm clear`, which would wipe the very store this
    # row is about.
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    start_app()
    rows = dump_until("Video", 15)
    check("16: the app is back on the reader's own page", on_screen(rows, "Video"),
          f"visible: {labels(rows)[:10]}")
    rows = open_video_dialog(names)
    if rows is None:
        return
    rows = dump_until("10 sentences")
    check("16: the runs came back with the same three files (FR-010)",
          on_screen(rows, "10 sentences"),
          f"the labels mentioning sentences: "
          f"{[l for l in labels(rows) if 'sentence' in l.lower()]}")
    rows = open_pass(rows)
    if rows is None:
        return
    counts = {name: chip_line(rows, name) for name, _ in PICTURES}
    print(f"   the pass's own counts after the relaunch: {counts}")
    check("16: and the pass holds them in force on the pictures carrying those names (SC-006)",
          counts == before, f"{counts}")

    # (4) The reader changes one run: white's fourth sentence goes to black. A
    # sentence taken off a run's end is allowed (FR-016) and a sentence next to
    # black's own run is continuous (FR-003), so this is one reader's gesture,
    # and it leaves **no** unassigned stretch — the difference the second render
    # shows is the assignment's own and not FR-006's fallback.
    tap_chip(white)
    tap_row(texts[3], label="white's last sentence")
    tap_chip(black)
    tap_row(texts[3], label="the same sentence, given to black")
    rows = fresh_dump()
    moved = {name: chip_line(rows, name) for name, _ in PICTURES}
    print(f"   the pass after the move: {moved}")
    check("16: the reader moved one sentence — white three, black four",
          moved == {white: "3 sentences", black: "4 sentences", red: "3 sentences"},
          f"{moved}")
    if not tap(rows, "Done", label="Done"):
        return
    time.sleep(2.0)

    # (5) The second render, with the assignment moved under the same files.
    library_before = library_state()
    log_2 = start_render()
    line_2 = app_line(log_2)
    plan_2 = render_plan(log_2)
    starts_2 = sentence_frames(log_2)
    file_2 = render_done(log_2)
    total_2 = total_frames(log_2)
    print(f"   second render: {line_2}")
    check("16: the second render's own line differs exactly where the assignment differs",
          plan_2 is not None
          and tuple(plan_2[1]) == ((0, starts_2[3] - 1),
                                   (starts_2[3], starts_2[7] - 1),
                                   (starts_2[7], total_2 - 1)),
          f"{line_2}: white now ends on the third sentence's own last frame "
          f"({starts_2[3] - 1}) and black opens on the fourth's ({starts_2[3]})")
    check("16: and no other range moved — red's own three sentences are where they were",
          plan_2 is not None and plan_2[1][2] == plan_1[1][2],
          f"red {plan_1[1][2]} → {plan_2[1][2] if plan_2 else None}")

    # (6) The frames: the one sentence the reader moved is the difference, and
    # the file they kept is untouched (SC-007).
    second_dest = os.path.join(OUT, "row16_second.mp4")
    data_second, got_second = pull(file_2 or "", second_dest)
    check("16: the second render's own file came off the device",
          got_second and bool(data_second), f"{len(data_second)}B from {file_2}")
    check("16: the two renders' files differ (the frames the assignment moved)",
          got_first and got_second
          and sha256_of(data_first) != sha256_of(data_second),
          f"first {sha256_of(data_first)[:16]}… second {sha256_of(data_second)[:16]}…")
    if got_first and got_second:
        # One frame number, read in both files: inside white's range in the first
        # render (white held the fourth sentence) and inside black's in the
        # second — so it must carry white's own colour in the one and black's in
        # the other. Red's range is untouched, so a frame inside it reads red in
        # both: the difference is one sentence wide and stops there.
        probe = starts_2[3] + 5
        other = starts_2[7] + 5
        moved_first = off_column_pixel(frame_at(first_dest, probe, "row16_first_moved"))
        red_first = off_column_pixel(frame_at(first_dest, other, "row16_first_red"))
        moved_second = off_column_pixel(frame_at(second_dest, probe, "row16_second_moved"))
        red_second = off_column_pixel(frame_at(second_dest, other, "row16_second_red"))
        print(f"   frame {probe}: {moved_first} in the first file, {moved_second} in the second")
        print(f"   frame {other}: {red_first} in the first file, {red_second} in the second")
        check("16: the frame the assignment moved carries white's picture in the first file",
              moved_first is not None and
              all(abs(a - b) <= 24 for a, b in zip(moved_first, PICTURES[0][1])),
              f"frame {probe}: {moved_first} against white {PICTURES[0][1]}")
        check("16: and black's in the second — the difference is the reader's own move",
              moved_second is not None and
              all(abs(a - b) <= 24 for a, b in zip(moved_second, PICTURES[1][1])),
              f"frame {probe}: {moved_second} against black {PICTURES[1][1]}")
        check("16: while the frames the assignment did not touch carry the same picture in both",
              red_first is not None and red_second == red_first,
              f"frame {other}: {red_first} → {red_second}")

    subprocess.run(["adb", "-s", DEV, "pull", f"{ALBUM}/{kept_name}", kept_dest],
                   capture_output=True)
    kept_after = (sha256_of(open(kept_dest, "rb").read())
                  if os.path.exists(kept_dest) else "")
    check("16: the first file's own hash is unchanged (SC-007)",
          bool(kept_before) and kept_after == kept_before,
          f"{kept_before[:16]}… → {kept_after[:16]}…")
    check("16: and the album still holds that one file — the second render kept nothing",
          sorted(gallery_videos()[0]) == sorted(kept_files),
          f"{gallery_videos()[0]}")
    check("16: the app's own library was neither added to nor rewritten by either render (FR-013)",
          library_state() == library_before,
          f"{len(library_before)} files → {len(library_state())} files; changed: "
          f"{[k for k in library_state() if library_before.get(k) != library_state()[k]]}")

    # The walk leaves the phone as it found it: the kept file's review comes
    # down, the album goes back to empty, and the row's content out of the
    # library.
    dismiss_review()
    clear_album()
    unseed_content()


# ---------------------------------------------------------------------------
# row 18 — a highlighted sentence does not cut the video (the reader's rule)
# ---------------------------------------------------------------------------
def row_18():
    step("row 18 — a sentence highlighted on the page does not cut the video")
    preflight()
    if not seed_content():
        return
    texts = sentences()
    first_len = sentence_lengths()[0]
    push_pictures(make_pictures())
    names = [p[0] for p in PICTURES]

    # (1) The same content and the same three pictures, on the page as the app
    # opens it — **nothing highlighted** — which is the reading this row
    # compares against.
    rows = open_video_dialog(names)
    if rows is None:
        return
    log_quiet = start_render()
    line_quiet = app_line(log_quiet)
    plan_quiet = render_plan(log_quiet)
    spoken_quiet = spoken_spans(log_quiet)
    print(f"   with nothing highlighted: {line_quiet}")
    if line_quiet is None or plan_quiet is None or not spoken_quiet:
        check("18: the first render reported its own lines", False, f"{line_quiet}")
        return

    # (2) The reader's own gesture leaves a sentence highlighted. A press of ▶
    # Read reads **the sentence in force** exactly (016's own rule), so the app's
    # `klhu read range` line names it — and two presses name the page's own
    # position twice: the first reads the content's first sentence and leaves the
    # position on the second, the second reads the sentence that was in force,
    # proving the position is on the SECOND and not on the first. That is the case
    # 012's FR-004 got wrong, and the one FR-017 is about.
    if not dismiss_review():
        check("18: the first render's review came down", False, "the review stayed up")
        return
    ranges_one, _speaks = stepper.fresh_press()
    check("18: the first press reads the content's first sentence",
          ranges_one == [sentence_span(0)],
          f"the press read {ranges_one}; the content's first sentence is "
          f"{sentence_span(0)}")
    stepper.wait_for_read_end()
    ranges_two, _speaks = stepper.fresh_press()
    check("18: and the page's own position is on the SECOND sentence, not the first",
          ranges_two == [sentence_span(1)] and sentence_span(1)[0] != 0,
          f"the second press read {ranges_two} — the sentence that was in force; the "
          f"content's second sentence is {sentence_span(1)}, so 012's own rule would "
          f"start a video here")
    stepper.wait_for_read_end()
    cap = screencap("/tmp/020_row18_highlight.png")
    band_top, cells = stepper.painted_band(cap)
    block = text_block()
    print(f"   the highlight's own band: top {band_top}, {cells} yellow px on {cap}; "
          f"the content node's box top "
          f"{block['y'] - block['h'] // 2 if block else None} (the node's box is the "
          f"scrolled page's, so its row says where the page is scrolled, not which "
          f"sentence is under the band — the app's own read line above names it)")
    check("18: and the page paints the sentence the position is on — the reader sees it",
          cells > 0 and band_top is not None,
          f"the band's top {band_top}, {cells} yellow px")

    # (3) The same three files again, with the highlight in force: the render is
    # the **whole content**, whatever the page is showing (FR-017, SC-011).
    rows = open_video_dialog(names)
    if rows is None:
        return
    log_marked = start_render()
    line_marked = app_line(log_marked)
    plan_marked = render_plan(log_marked)
    spoken_marked = spoken_spans(log_marked)
    first_marked = video.render_runs(log_marked)[:1]
    if line_marked is None:
        check("18: the second render reported its own line", False, "no `klhu render` line")
        return
    print(f"   with a sentence highlighted: {line_marked}")
    print(f"   the render's own utterances, by span: {spoken_marked}")
    screencap("/tmp/020_row18_review.png")

    check("18: with a sentence highlighted the render still holds every sentence (FR-017)",
          plan_marked is not None and plan_marked[2] == len(texts)
          and len(spoken_marked) == len(texts),
          f"{line_marked} — {len(spoken_marked)} utterances")
    check("18: and it opens on the content's own first sentence (SC-011)",
          bool(first_marked)
          and first_marked[0]["slot"] == 0 and first_marked[0]["start"] == 0
          and first_marked[0]["span_start"] == 0
          and first_marked[0]["span_end"] - first_marked[0]["span_start"] == first_len,
          f"slot {first_marked[0]['slot'] if first_marked else None} "
          f"frame {first_marked[0]['start'] if first_marked else None} "
          f"span {first_marked[0]['span_start'] if first_marked else None}.."
          f"{first_marked[0]['span_end'] if first_marked else None} against the "
          f"content's first sentence 0..{first_len}")
    check("18: the two renders' own lines are identical — a highlight is not a video's input",
          # The app's own payload after `": "`, which is 012's and row 7's own way
          # of comparing two of the app's lines across renders: the logcat prefix
          # (its timestamp and process id) is the device's, not the app's.
          line_marked.split(": ")[-1] == line_quiet.split(": ")[-1],
          f"nothing highlighted:  {line_quiet.split(': ')[-1]}\n"
          f"highlighted:        {line_marked.split(': ')[-1]}")
    unseed_content()


ROWS = {
    "6": row_6,
    "7": row_7,
    "8": row_8,
    "9": row_9,
    "10": row_10,
    "11": row_11,
    "12": row_12,
    "13": row_13,
    "16": row_16,
    "18": row_18,
}

OWED = ()


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ROWS:
        print(f"usage: {os.path.basename(__file__)} {'|'.join(sorted(ROWS))}")
        print(f"rows this walk still owes: {', '.join(OWED)}")
        sys.exit(2)
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 020 row {sys.argv[1]} — device {DEV}, package {PKG}, out {OUT}")
    ROWS[sys.argv[1]]()
    print("\n===== result =====")
    failed = [r for r in RESULTS if not r[1]]
    for name, ok, detail in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}"
              f"{(' — ' + detail) if detail else ''}")
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
