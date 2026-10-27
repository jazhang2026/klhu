#!/usr/bin/env python3
"""klhu device walk — 025 quickstart row 4.

Row 4: the import end to end — a real document through the seam, the read and
        the render (FR-001–FR-004, SC-001–SC-003 on a real file).

This row drives the reader's OWN path: a real document file on the phone's
storage, the app's own import button, the platform's own file dialog walked
from its roots to the file, and then the content the import produced — read
from the top and rendered. Nothing is seeded into the content store: the
content this row measures is the one the app made.

  - the document: `klhu025_import.txt`, pushed to /sdcard/Download/ — a file
    outside the app, on the device's shared storage, which is what "the reader
    feeds a document" means.
  - the import: the reading page's own import tab, then DocumentsUI's own roots
    (`Show roots` → `Downloads` → the file's exact title). The picker's labels
    are the PLATFORM's, in this device's language, so the row navigates by the
    path a reader walks rather than by whatever surface happens to come first;
    the app's labels are read out of `lib/l10n/app_*.arb` (whichever locale the
    device draws), never re-typed here.
  - the read: one `Continue Read` press. On this tree that press reads the whole
    content from offset 0 and the app logs ONE `klhu read range: 0..N` for it
    plus one `klhu speak` line per sentence — so one range against N sentences
    is the app's shape, not a short read (measured 2026-10-26; the earlier cut of
    this row expected N ranges and read the app's own line as a defect).
  - the render: the `Video` tab's own prompt, one `Start`, one video.

The row leaves its imported content behind (it is the app's own content, made
through the reader's own gesture); its checks are measured against the store as
it stands at the start of each run, so a re-run is not confused by the last
one's content.

Usage:  /usr/bin/python3 -u klhu_walk_document.py 4
        ADB_SERIAL=emulator-5554 KLHU_DEV=emulator-5554 /usr/bin/python3 -u klhu_walk_document.py 4
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.
"""
import json
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
video = base.video
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
wait_for = base.wait_for
clear_logcat = base.clear_logcat
logcat = base.logcat
start_app = base.start_app
start_render = base.start_render
render_plan = base.render_plan
render_report = base.render_report
spoken_spans = base.spoken_spans
cat = base.cat
PKG = base.PKG
DEV = base.DEV
OUT = base.OUT
RESULTS = base.RESULTS
LIBRARY = f"/data/user/0/{PKG}/app_flutter"

# The one real document file this row walks: a prose document on the device's
# own storage, its text the row reads back out of the store and the read speaks.
FIXTURE_NAME = "klhu025_import.txt"
DEVICE_PATH = f"/sdcard/Download/{FIXTURE_NAME}"
# The document carries a run-unique sentence, so "the document's text reached the
# page / the store" can never be satisfied by the content an EARLIER run left
# open (a row whose two sides are equal by construction is not a check).
RUN_TAG = time.strftime("%m%d-%H%M%S")
TEXT = (
    "深秋的夜来得很早。\n"
    "人们说，等一等，月亮就出来。\n"
    "河面上有一艘船，船上有三个人，他们在看月亮。\n"
    "月亮很大，很大，又被云慢慢遮住，遮住，又露出来。\n"
    "夜很黑，河很静，水面上有一层薄薄的光。\n"
    "\n"
    "灯塔在河边，它看见了这一切。\n"
    "它比月亮更早看见夜。\n"
    f"第{RUN_TAG}次文档输入走查。\n"
)

SENTENCE_END = ".!?;。！？；"
# The app's own lines, cut to their payload (§19): `klhu read range: 0..120`,
# `klhu speak p0 s0 "<the sentence>"`.
RANGE_RE = re.compile(r"klhu read range: (\d+)\.\.(\d+)")
SPEAK_RE = re.compile(r'klhu speak [^"]*"([^"]*)"')


def app_sentences(text):
    """The sentences the app speaks, by the app's own rule: blank lines cut
    paragraphs, and `. ! ? ; 。！？；` (plus ASCII `...`) end a sentence."""
    out = []
    for para in re.split(r"\n[ \t]*\n+", text):
        buf, i = "", 0
        while i < len(para):
            ch = para[i]
            buf += ch
            if ch in SENTENCE_END or para.startswith("...", i) or \
                    para.startswith("……", i):
                out.append(buf.strip())
                buf = ""
            i += 1
        if buf.strip():
            out.append(buf.strip())
    return [s for s in out if s]


def arb_value(key):
    """The app's own string for [key], in whichever locale the device draws.

    Read out of `lib/l10n/app_*.arb` — the file of record — instead of being
    re-typed here, so a row that taps `Import document` is proving the app
    draws its ARB value and not a copy of the row's own text (§16).
    """
    values = []
    for locale in ("en", "zh", "zh_Hans", "es"):
        with open(os.path.join(REPO, "lib", "l10n", f"app_{locale}.arb"),
                  encoding="utf-8") as fh:
            value = json.load(fh).get(key)
        if value and value not in values:
            values.append(value)
    return values


def on_screen_label(rows, key):
    """Which of [key]'s own strings this screen draws, or None."""
    for value in arb_value(key):
        if any((r["desc"] or r["text"]) == value for r in rows):
            return value
    return None


def newest_source():
    """(mtime, path) of the newest file the installed app is built from."""
    newest, where = 0.0, ""
    for top in ("lib", os.path.join("android", "app", "src")):
        for dirpath, _, files in os.walk(os.path.join(REPO, top)):
            for name in files:
                path = os.path.join(dirpath, name)
                mtime = os.path.getmtime(path)
                if mtime > newest:
                    newest, where = mtime, path
    return newest, where


def push_fixture():
    """The document, on the device's own shared storage. Answers its size."""
    local = os.path.join(OUT, FIXTURE_NAME)
    os.makedirs(OUT, exist_ok=True)
    with open(local, "w", encoding="utf-8") as fh:
        fh.write(TEXT)
    adb("push", local, DEVICE_PATH)
    # The media scanner, so the platform's own picker sees the file at once.
    adb("shell", "am", "broadcast", "-a",
        "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
        "-d", f"file://{DEVICE_PATH}")
    time.sleep(1.5)
    listing = adb("shell", "ls", "-l", DEVICE_PATH).stdout.strip()
    return listing


def store_index():
    """The app's own content index, as the store wrote it."""
    return json.loads(cat(f"{LIBRARY}/content/index.json").decode("utf-8"))


def store_files():
    """Every file under the app's own store root."""
    return [line.strip() for line in
            adb("shell", "run-as", PKG, "find", LIBRARY, "-type", "f"
                ).stdout.splitlines() if line.strip()]


def cache_copies():
    """Every copy of the fixture under the app's own cache.

    That is where `file_selector` stages a picked `content://` file
    (`FileUtils.java`: `{cacheDir}/{uuid}/{name}`), and where the reader's own
    rule (2026-10-26: 内存副本只用于阅读，读完即焚) says nothing may be left once the
    bytes are in memory.
    """
    return [line.strip() for line in
            adb("shell", "run-as", PKG, "find", f"/data/data/{PKG}/cache",
                "-name", FIXTURE_NAME).stdout.splitlines() if line.strip()]


def page_content(rows):
    """The page's painted content node — the label carrying the document's own
    first sentence, so a toolbar or a message can never answer for it."""
    first = TEXT.splitlines()[0]
    for r in rows:
        label = (r["desc"] or r["text"]).strip()
        if label.startswith(first):
            return label
    return ""


def walk_picker_to(name):
    """The platform's own dialog, from its roots to the file called [name].

    Never the landing surface: DocumentsUI opens on `Recent files`, whose rows
    change with the device's state, so a row that matched a name there would be
    walking the screen rather than the path a reader walks (§2).
    """
    rows = dump_until("Show roots", seconds=12)
    if not on_screen(rows, "Show roots"):
        check("4: the platform's picker opened on the app's tap (FR-001)", False,
              f"on screen: {labels(rows)[:10]}")
        return False
    check("4: the platform's picker opened on the app's tap (FR-001)", True,
          f"DocumentsUI, on its own surface: {labels(rows)[:4]}")
    tap(rows, "Show roots", exact=False, label="Show roots")
    rows = dump_until("Downloads", seconds=10)
    if not any((r["desc"] or r["text"]) == "Downloads" for r in rows):
        check("4: the picker offers the device's own roots", False,
              f"the roots it drew: {labels(rows)[:10]}")
        return False
    tap(rows, "Downloads", exact=True, label="Downloads")
    rows = dump_until(name, seconds=10)
    shown = [t for t in labels(rows) if t.endswith(".txt")]
    if not any((r["desc"] or r["text"]) == name for r in rows):
        check("4: the document is listed in the device's Downloads", False,
              f"the .txt names it listed: {shown[:8]}")
        return False
    check("4: the document is listed in the device's Downloads, by its own name",
          True, f"{shown[:4]}")
    tap(rows, name, exact=True, label=name)
    return True


def row_4():
    base.step("row 4 — the import end to end: a real document file, the read "
              "and the render")

    # §14: the device drives the BUILD, so the build is named before the row.
    apk = os.path.join(REPO, "build", "app", "outputs", "flutter-apk",
                       "app-debug.apk")
    if not os.path.exists(apk):
        check("4: the device holds a build of this tree", False,
              f"no debug APK at {apk} — build and install before walking")
        return
    built = os.path.getmtime(apk)
    newest, where = newest_source()
    check("4: the device holds a build of this tree", newest <= built,
          f"APK {'newer' if newest <= built else 'OLDER'} than "
          f"{os.path.relpath(where, REPO)} "
          f"({time.strftime('%H:%M:%S', time.localtime(max(built, newest)))})")

    # The store as the row finds it: every check below is measured against it.
    before = {e["id"] for e in store_index().get("entries", [])}
    before_files = store_files()
    print(f"   the store before the import: {len(before)} contents, "
          f"{len(before_files)} files")

    # Copies left in the cache by runs that predate the burn-after-read fix
    # (2026-10-26) are cleared here, so the SC-003 check below is about THIS
    # pick and not about the past.
    stale = cache_copies()
    if stale:
        adb("shell", "run-as", PKG, "find", f"/data/data/{PKG}/cache",
            "-name", FIXTURE_NAME, "-delete")
        print(f"   cleared {len(stale)} cache cop(ies) left by earlier runs")

    listing = push_fixture()
    check("4: the document is a real file on the device's own storage",
          FIXTURE_NAME in listing, listing or "ls printed nothing")
    if FIXTURE_NAME not in listing:
        return

    # The app's own page, freshly started: the import lives on it.
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    start_app()
    rows = fresh_dump()
    deadline = time.time() + 20
    while time.time() < deadline and on_screen_label(
            rows, "importDocumentButton") is None:
        time.sleep(1)
        rows = fresh_dump()
    label = on_screen_label(rows, "importDocumentButton")
    check("4: the reading page offers the import (FR-001)", label is not None,
          f"the page draws {label!r}" if label else
          f"on screen: {labels(rows)[:12]}")
    if label is None:
        return
    tap(rows, label, exact=True, label="the import button")
    if not walk_picker_to(FIXTURE_NAME):
        return

    # The seam's own answer, on the page: the document's text, whole.
    painted = ""
    deadline = time.time() + 25
    while time.time() < deadline:
        painted = page_content(dump())
        if painted.strip():
            break
        time.sleep(1)
    check("4: the picked document's text reached the reading page, whole",
          painted.strip() == TEXT.strip(),
          f"{len(painted.strip())} chars painted, the document holds "
          f"{len(TEXT.strip())}")

    # The landing (FR-004): exactly one new content, an ordinary user content.
    after_index = store_index()
    after = {e["id"] for e in after_index.get("entries", [])}
    new_ids = sorted(after - before)
    check("4: the import added exactly one content to the library (FR-004)",
          len(after) == len(before) + 1 and len(new_ids) == 1,
          f"{len(before)} before, {len(after)} after, new: {new_ids}")
    if not new_ids:
        return
    entry = next(e for e in after_index["entries"] if e["id"] == new_ids[0])
    # The store names a content after its own first line and disambiguates a
    # second content with the same name (`… (2)`), so the name is matched by its
    # own first line rather than by equality.
    check("4: the imported content is an ordinary user content (FR-004)",
          entry.get("origin") == "user"
          and entry.get("language") == "zh-Hans"
          and str(entry.get("name", "")).startswith(TEXT.splitlines()[0]),
          f"the entry: {{'origin': {entry.get('origin')!r}, "
          f"'language': {entry.get('language')!r}, 'name': {entry.get('name')!r}}}")

    body = cat(f"{LIBRARY}/content/contents/{new_ids[0]}.txt").decode(
        "utf-8", "replace")
    check("4: the content that landed is the document's extracted text "
          "(SC-001, SC-003)", body == TEXT,
          f"{len(body)} chars stored, {len(TEXT)} in the document")

    # SC-003 / FR-003: nothing of the document is left on disk — not in the
    # app's own store (the content is the extracted text) and not in the cache
    # `file_selector` stages a pick in, which the app burns as soon as the bytes
    # are in memory.
    staged = [p for p in store_files() if FIXTURE_NAME in p]
    check("4: no copy of the picked document in the app's own store (SC-003)",
          not staged, f"staged: {staged}" if staged else
          f"the store root holds {len(store_files())} files, none of them the "
          f"document")
    left = cache_copies()
    check("4: the document's staged copy is burned once its bytes are read "
          "(SC-003)", not left,
          f"left on disk: {left}" if left else
          "the app's cache holds no copy of the document")

    # The read: one press of Continue Read, the app's own lines.
    clear_logcat()
    rows = fresh_dump()
    continue_label = on_screen_label(rows, "continueReadButton")
    check("4: the imported page offers the read from the top",
          continue_label is not None, f"it draws {continue_label!r}")
    if continue_label is None:
        return
    tap(rows, continue_label, exact=True, label="Continue Read")
    read_labels = arb_value("readButton")
    ended = wait_for(lambda: any((r["desc"] or r["text"]) in read_labels
                                 for r in dump()), seconds=150)
    log = logcat()
    spoken = SPEAK_RE.findall(log)
    ranges = [(int(a), int(b)) for a, b in RANGE_RE.findall(log)]
    expected = app_sentences(TEXT)
    print(f"   the app logged {len(ranges)} range(s) and {len(spoken)} "
          f"utterance(s) for {len(expected)} sentences")

    check("4: the read of the document ran to its end", bool(ended),
          "the toolbar's Read came back" if ended else
          "the toolbar still offers no Read")
    check("4: one press read the whole document (its own range)",
          ranges == [(0, len(TEXT))],
          f"the range: {ranges}, the document is {len(TEXT)} chars")
    check("4: the read speaks the document's own sentences, in order, whole",
          spoken == expected,
          f"{len(spoken)} spoken of {len(expected)}: {spoken[:2]} …")
    oom = [line for line in log.splitlines()
           if "OOM" in line or "OutOfMemory" in line]
    check("4: the read of the document completed without exhausting memory "
          "(SC-002)", not oom, f"{len(oom)} OOM lines")

    # The render: the imported content's own video, one slot per sentence.
    rows = fresh_dump()
    video_label = on_screen_label(rows, "videoButton")
    check("4: the imported content's page offers the video tab",
          video_label is not None, f"it draws {video_label!r}")
    if video_label is None:
        return
    tap(rows, video_label, exact=True, label="Video")
    rows = dump_until(arb_value("videoStartButton")[0], seconds=12)
    check("4: the imported content offers the render (SC-001)",
          on_screen(rows, "Start"), f"on screen: {labels(rows)[:10]}")
    if not on_screen(rows, "Start"):
        return
    log = start_render(seconds=300)
    plan = render_plan(log)
    report = render_report(log)
    spans = spoken_spans(log)
    check("4: the render's own schedule counts the document's sentences "
          "(SC-001)", plan is not None and plan[2] == len(expected),
          f"plan: {plan}, the document holds {len(expected)} sentences")
    check("4: the render wrote its video and reported frames (SC-001)",
          report is not None and report[3] > 0, f"report: {report}")
    check("4: every render slot is one of the document's own sentences",
          len(spans) == len(expected),
          f"{len(spans)} slots, {len(expected)} sentences")


ROWS = {
    "4": row_4,
}


def main():
    if len(sys.argv) != 2 or sys.argv[1] not in ROWS:
        print("usage: klhu_walk_document.py <%s>" % "|".join(sorted(ROWS)))
        return 2
    base.preflight()
    # A re-run's own boot: a dialog or a picker left up by a killed run (§28).
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
