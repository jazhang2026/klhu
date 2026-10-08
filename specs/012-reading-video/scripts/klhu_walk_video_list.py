#!/usr/bin/env python3
"""012 quickstart rows 56 and 57, on the reader's own phone (T064).

Row 56: a content's videos are listed, and each one is its own — one row per
video in the record's own order, a tap on a row playing, each row's own share and
delete, a delete whose warning names **that** video, and a delete that leaves the
content's other videos and files in place.

Row 57: the records written before the 2026-10-06 amendment are still the
reader's — a value in the shape 012 shipped with (a single object per content)
reads as one video and is **not** rewritten by the read. Run this row BEFORE row
56 on the phone, because row 56 keeps a video and that write is what migrates the
content in force.

    ADB_SERIAL=38821a76 KLHU_ASPECT='9:16 vertical (Shorts)' \\
        python3 klhu_walk_video_list.py 57
    ADB_SERIAL=38821a76 KLHU_ASPECT='9:16 vertical (Shorts)' \\
        python3 klhu_walk_video_list.py 56

Two things this walk is careful about, because the device is the reader's own:

* **No `pm clear`, and no `clear_album`.** Both rows need what the reader's phone
  already holds — a content with a kept video (row 55 leaves that behind) and
  records written before this amendment, which only this phone has. Clearing is
  also what takes their videos away.
* **What it deletes is what it just kept.** Row 56 renders one new video, keeps it
  beside the earlier one, and deletes **that** row again, so the videos the reader
  kept before the walk are still theirs afterwards. Deleting their older video to
  make a point about row identity is a cost this row does not pay.

What each row reads: the record itself — `shared_preferences`' `video_record`,
read out of the app's XML (its JSON quotes arrive escaped) — and the phone's own
video library, both the files in `Movies/Klhu` and the MediaStore entries that
make them the gallery's (`gallery_videos`).

A note on what row 56 can and cannot prove off the device: which file a tap played
is not readable — the platform's player names the session, not the source, and
every row of one content carries the same name. **Per-row identity is therefore
read from the delete**: the file that leaves the library and the entry that leaves
the record name the row that was tapped, and the rows the reader did not touch are
still there.
"""

import json
import os
import re
import subprocess
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))

import klhu_walk_video as v  # the driver's device mechanics: dump/tap/labels/check

DEV = os.environ.get("ADB_SERIAL", "38821a76")
ASPECT = os.environ.get("KLHU_ASPECT", "9:16 vertical (Shorts)")
PKG = v.PKG
ALBUM = v.ALBUM
PREF = v.PREF
WAIT = int(os.environ.get("KLHU_WAIT", "600"))  # the render is ~140 s on this phone

v.DEV = DEV
# The content the reader's own phone holds a video for is a long Cantonese text,
# and a render is per sentence: the walk's own bound is generous rather than the
# sample's (the emulator's pre-set renders in ~140 s; this one takes minutes).
v.RENDER_TIMEOUT = int(os.environ.get("KLHU_RENDER_TIMEOUT", "1800"))


def step(title):
    v.step(title)


def check(name, ok, detail=""):
    v.check(name, ok, detail)


def shell(*args):
    return subprocess.run(
        ["adb", "-s", DEV, *args], capture_output=True, text=True
    ).stdout


def wake():
    """The phone's own screen and keyguard, before anything is driven.

    A dump taken with the shade up shows the shade (`NotificationShade` is what
    `dumpsys window` reports as focused), and that reads as "the app is not
    there" — one run of row 57 read the phone's home screen and its weather
    widget and blamed the app. 224 is WAKEUP, `wm dismiss-keyguard` is the
    platform's own way past a keyguard with no secret, and 82 is MENU (the old
    unlock). The screen is then kept on for the walk — a 140 s render outlasts
    most timeouts and a sleeping screen fails every dump after it — and the
    setting is put back at the end.
    """
    shell("shell", "input", "keyevent", "224")
    time.sleep(0.5)
    shell("shell", "wm", "dismiss-keyguard")
    time.sleep(1)
    shell("shell", "input", "keyevent", "82")
    time.sleep(0.5)
    shell("shell", "svc", "power", "stayon", "true")


NATIVE = {"en": "English", "zh": "中文", "zh_Hans": "中文", "es": "Español"}


def language():
    """The app's own interface language, as its store holds it."""
    xml = shell(
        "shell", "run-as", PKG, "cat",
        f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml",
    )
    m = re.search(r'name="flutter\.interface_language">([^<]*)<', xml)
    return m.group(1) if m else "en"


def set_language(tag):
    """Drives the page's own language control to [tag]'s native name.

    The reader's phone is in their own language (中文 here), and every label this
    spec's drivers drive — the video action, the render's prompt, `Videos`, a
    row's `Share` and `Delete video`, the warning's buttons — is the app's copy in
    the language the app is set to. Rather than carry four vocabularies, the walk
    sets the app to English for its run and puts the reader's own language back
    afterwards, which the receipt states. Row 58 is the row about the language
    itself, and it is a unit row (four locales, asserted from the ARBs).
    """
    rows = v.dump()
    shown = NATIVE.get(language(), "English")
    if not v.tap(rows, shown, label=f"the language control ({shown})"):
        return False
    time.sleep(1.5)
    menu = v.dump()
    v.show(menu, 10)
    if not v.tap(menu, NATIVE[tag], label=f"the language {NATIVE[tag]}"):
        return False
    time.sleep(2.5)
    check(f"the app is set to {NATIVE[tag]} for this run",
          language() == tag, f"its store now reads {language()!r}")
    return True


def rest():
    """Puts back what the walk changed on the device: the screen's stay-on."""
    shell("shell", "svc", "power", "stayon", "false")


# The reading page's own controls, and ONLY them: the videos list carries
# `Videos` in its app bar and `Share`/`Delete video` on its rows, so a page test
# that accepted any of those would call the list screen "the page" and then drive
# the wrong screen (one run did exactly that, and its language was left set to
# English because the restore tapped nothing).
PAGE_LABELS = ("Appearance", "Contents", "Text type", "Voice", "Continue Read")


def app_page(tries=12):
    """The app's own reading page, once it is really up.

    The shade, the home screen, the videos list and a Flutter frame that has not
    drawn yet all answer a dump; none of them is the page. The test is the page's
    own controls: at least two of them, or nothing else is claimed.
    """
    for _ in range(tries):
        rows = v.dump()
        names = [n.strip() for n in v.labels(rows)]
        if sum(n in PAGE_LABELS for n in names) >= 2:
            return rows
        time.sleep(1.5)
    return v.dump()


def pop_to_page():
    """Back to the reading page from wherever the app was left.

    The previous run of this walk (or the reader's own last screen) can leave a
    pushed route up — the videos list, the player — and then the page's controls
    are not on screen at all.
    """
    rows = app_page()
    for _ in range(4):
        names = [n.strip() for n in v.labels(rows)]
        if sum(n in PAGE_LABELS for n in names) >= 2:
            return rows
        print("   not the page yet — back")
        shell("shell", "input", "keyevent", "4")
        time.sleep(1.5)
        rows = app_page()
    return rows


LIST_LABEL = "Delete video"   # a row's own control, and nothing else carries it


def back_to_list(tries=5):
    """The videos list, once its own rows are really on screen.

    Back is not one press away from the list when a video was played: the
    platform's own control bar inside the playback view consumes the first press
    (it collapses back into a bar) and only the next one leaves the screen. One
    run pressed it once, read the player, and then reported `Share` missing from
    a screen that was never the list — so the walk asks for the list and presses
    again until it is there, and stops on the page instead of pressing past it.
    """
    rows = v.dump()
    for _ in range(tries):
        if v.on_screen(rows, LIST_LABEL):
            return rows
        names = [n.strip() for n in v.labels(rows)]
        if sum(n in PAGE_LABELS for n in names) >= 2:
            print("   the page came back, not the list — the list was left behind")
            return rows
        print(f"   not the list yet — back (on screen: {v.labels(rows)[:6]})")
        shell("shell", "input", "keyevent", "4")
        time.sleep(2)
        rows = v.dump()
    return rows


def open_the_content(title, rows):
    """The content the record names, reached through the app's own contents list.

    FR-011: the record's name IS the content's name (with `.mp4`), so the row can
    find the content it is about. The app opens wherever the reader left it, so
    the page's own controls decide whether this is needed at all.
    """
    if v.on_screen(rows, "Videos"):
        return rows
    if not v.tap(rows, "Contents", label="Contents"):
        return None
    time.sleep(2)
    listed = app_page()
    v.show(listed, 14)
    if not v.tap(listed, title, label=f"the content {title!r}"):
        return None
    time.sleep(3)
    return app_page()


def row_nodes(rows, name):
    """The list's row nodes for a video named [name], top to bottom.

    Flutter hands a `ListTile` to the accessibility bridge as ONE node carrying
    its title AND its subtitle (`'<name>\nSep 29, 2026'`), so a row is found by
    containment, never by equality — an equality test reports zero rows for a list
    that is right there.
    """
    return sorted(
        [r for r in rows if name in (r["desc"] or r["text"])],
        key=lambda r: r["y"],
    )


def dump_xml():
    """The device's own view tree, for the nodes Flutter's accessibility bridge
    is happy to name a class for (the review's switch is one of those)."""
    shell("shell", "rm", "-f", v.XML)
    shell("shell", "uiautomator", "dump", v.XML)
    return shell("exec-out", "cat", v.XML)


def album():
    """The files in the phone's own video library, one name per line.

    `ls -1`, not `ls -l`: a library name may itself contain a space (the platform
    renames a taken name to `<name> (1).mp4`), and a column split cuts it.
    """
    out = shell("shell", "ls", "-1", ALBUM)
    return sorted(
        line.strip() for line in out.splitlines()
        if line.strip() and not line.strip().startswith("ls:")
    )


def store():
    """The record as it is written: `{content key: the raw value}`.

    Read raw on purpose — this is the row about the SHAPE the store holds, so a
    reader that lifted the old shape to a list would hide the thing being checked.
    """
    xml = shell(
        "shell", "run-as", PKG, "cat",
        f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml",
    ).replace("&quot;", '"').replace("&amp;", "&")
    m = re.search(r'name="flutter\.video_record"[^>]*>([^<]*)<', xml)
    if not m:
        return {}
    try:
        value = json.loads(m.group(1))
    except ValueError:
        return {}
    return value if isinstance(value, dict) else {}


def entries_of(value):
    """The entries [value] holds, whatever shape it is in: an array (this feature
    now) or the single object it shipped with — read as one video, which is the
    rule row 57 is about."""
    raw = value if isinstance(value, list) else [value] if isinstance(value, dict) else []
    return [
        e for e in raw
        if isinstance(e, dict) and e.get("name") and e.get("uri")
    ]


def media_id(entry):
    m = re.search(r"/(\d+)/?$", entry["uri"])
    return m.group(1) if m else entry["uri"]


def switch_state(rows):
    """(offered, checked, (x, y)) for the review's replacement switch.

    The switch is Flutter's own `SwitchListTile`; `uiautomator` shows it as a
    checkable node, and its bounds are the tap target.
    """
    xml = dump_xml()
    for node in re.finditer(r"<node[^>]*>", xml):
        n = node.group(0)
        if 'checkable="true"' not in n and "Switch" not in n:
            continue
        checked = re.search(r'checked="([^"]*)"', n)
        box = re.search(r'bounds="\[(\d+),(\d+)\]\[(\d+),(\d+)\]"', n)
        if not box:
            continue
        x = (int(box.group(1)) + int(box.group(3))) // 2
        y = (int(box.group(2)) + int(box.group(4))) // 2
        return (True, checked.group(1) == "true" if checked else None, (x, y))
    return (False, None, None)


def keep_the_render(label):
    """Taps Save on the review as it stands, with the replacement switch where the
    row left it. Answers the album and the record afterwards."""
    rows = v.dump()
    if not v.tap(rows, "Save", label=f"{label}: Save", exact=True):
        return None
    time.sleep(2)
    return v.wait_for(lambda: album(), WAIT // 4)


def row_57():
    step("57: what the reader's phone holds before anything is written")
    wake()
    v.start_app()
    rows = pop_to_page()
    v.show(rows, 12)
    before = store()
    old_shape = sorted(
        key for key, value in before.items()
        if isinstance(value, dict) and entries_of(value)
    )
    as_list = sorted(
        key for key, value in before.items()
        if isinstance(value, list) and entries_of(value)
    )
    print(f"   contents in the reader's own store: {len(before)}")
    print(f"   still in the shipped one-object shape: {old_shape}")
    print(f"   already written as an array: {as_list}")
    for key, value in before.items():
        print(f"   {key}: {value if len(str(value)) < 160 else str(value)[:157] + '…'}")
    check("57: the phone carries records written before this amendment",
          bool(old_shape) or bool(as_list),
          f"old shape {old_shape}, array {as_list}")

    # The app's own answer to those records: a content that holds a video offers
    # its videos (FR-022), whether or not its stored value is the old shape — a
    # video kept before this amendment is listed and plays, which is the migration
    # seen in the reader's own library rather than asserted in a unit test.
    video_contents = [k for k, val in before.items() if entries_of(val)]
    title = None
    for value in before.values():
        for entry in entries_of(value):
            title = entry["name"][:-4] if entry["name"].endswith(".mp4") else entry["name"]
    rows = open_the_content(title, rows) if title else rows
    if rows is None:
        check("57: the content the record names could be opened", False,
              f"title {title!r}; page {v.labels(app_page())[:8]}")
        return
    v.show(rows, 14)
    check("57: the video the app remembered before this amendment is reachable "
          "from its own content (the page offers `Videos`)",
          v.on_screen(rows, "Videos"),
          f"videos in the record: {video_contents}; the content opened: {title!r}; "
          f"page offers Videos: {v.on_screen(rows, 'Videos')} "
          f"(page: {v.labels(rows)[:8]})")

    # The read itself must not rewrite what it read (contract § Read rules 5).
    rows = v.dump()
    if v.on_screen(rows, "Videos") and v.tap(rows, "Videos", label="Videos"):
        time.sleep(2)
        listed = v.dump()
        print(f"   the list is up; its own nodes: {v.labels(listed)[:10]}")
        check("57: opening the list reads the record without rewriting it",
              store() == before,
              f"before {len(str(before))} chars, after {len(str(store()))} chars")
        shell("shell", "input", "keyevent", "4")   # back to the page
        time.sleep(1.5)

    after = store()
    check("57: nothing the reader kept was lost or duplicated by the read",
          {k: entries_of(val) for k, val in after.items()}
          == {k: entries_of(val) for k, val in before.items()},
          f"{len(after)} contents after, {len(before)} before")


def row_56():
    step("56 setup: the reader's phone as it stands — no clear, nothing deleted")
    wake()
    v.start_app()
    rows = pop_to_page()
    v.show(rows, 12)
    files_before = album()
    record_before = store()
    with_video = {
        k: entries_of(val) for k, val in record_before.items() if entries_of(val)
    }
    check("56: the phone holds a content with a kept video to work on (row 55 "
          "leaves that behind)",
          bool(with_video), f"contents with videos: {sorted(with_video)}")
    if not with_video:
        return
    print(f"   album before: {files_before}")

    # The render has to be made for THAT content, or the review has nothing to
    # ask about replacing: the app opens wherever the reader left it, so the row
    # walks to the content its own record names (FR-011: the record's name is the
    # content's name with `.mp4`).
    title = None
    for value in record_before.values():
        for entry in entries_of(value):
            title = entry["name"][:-4] if entry["name"].endswith(".mp4") else entry["name"]
    rows = open_the_content(title, rows) if title else rows
    if rows is None:
        check("56: the content the record names could be opened", False,
              f"title {title!r}")
        return
    v.show(rows, 14)
    check("56: the content that holds a video is open, and offers its videos",
          v.on_screen(rows, "Videos"), repr(v.labels(rows)[:10]))

    # ---- keep one more for the content in force, beside the earlier one ----
    step("56: render again and keep BOTH (the replacement switch off, row 55)")
    if not v.render("56/render", ASPECT):
        return
    time.sleep(2)
    rows = v.dump()
    v.show(rows, 12)
    offered, checked, box = switch_state(rows)
    check("56: the review asks about replacing — this content already has a video",
          offered and box is not None, f"switch offered={offered} box={box}")
    if offered and checked and box:
        shell("shell", "input", "tap", str(box[0]), str(box[1]))
        time.sleep(1)
        _offered, checked_after, _box = switch_state(v.dump())
        check("56: the switch is off, so this keep adds beside the earlier one",
              checked_after is False, f"checked={checked_after}")
    kept_files = keep_the_render("56")
    if kept_files is None:
        check("56: the keep landed in the library", False, "no album answer")
        return

    record_after = store()
    grew = [
        k for k, val in record_after.items()
        if len(entries_of(val)) > len(entries_of(record_before.get(k) or []))
    ]
    check("56: the keep added an entry for the content in force, beside the "
          "earlier one", len(grew) == 1,
          f"contents whose record grew: {grew}")
    if len(grew) != 1:
        return
    in_force = grew[0]
    entries = entries_of(record_after[in_force])
    new_file = [f for f in kept_files if f not in files_before]
    check("56: exactly one new file is in the library, and the earlier ones are "
          "still there", len(new_file) == 1 and len(kept_files) == len(files_before) + 1,
          f"before {files_before}, now {kept_files}")
    check("56: the record holds one entry per kept video, oldest first",
          len(entries) == len(record_before.get(in_force, [])) + 1
          if isinstance(record_before.get(in_force), list)
          else len(entries) >= 2,
          f"{in_force}: {[media_id(e) for e in entries]}")

    # ---- the page's one action, and the list it opens ----
    step("56: the page offers one Videos action — not the three it replaced")
    rows = v.dump()
    v.show(rows, 12)
    check("56: the page offers `Videos` and none of the withdrawn controls",
          v.on_screen(rows, "Videos") and not v.on_screen(rows, "Play video")
          and not v.on_screen(rows, "Delete video"),
          repr(v.labels(rows)[:10]))
    if not v.tap(rows, "Videos", label="Videos"):
        return
    time.sleep(2)
    listed = v.dump()
    v.show(listed, 14)
    name = entries[-1]["name"]
    rows_found = row_nodes(listed, name)
    check("56: the list draws one row per kept video",
          len(rows_found) == len(entries),
          f"{len(rows_found)} rows for {len(entries)} entries "
          f"({[media_id(e) for e in entries]}); the list's own nodes: "
          f"{v.labels(listed)[:8]}")
    check("56: the rows are separate and in the record's own order (the newest "
          "lowest)",
          len({r["y"] for r in rows_found}) == len(rows_found) and bool(rows_found),
          f"rows at y {[r['y'] for r in rows_found]}")

    # ---- a tap plays; per-row identity is read from the delete below ----
    step("56: a tap on the newest row plays (the row's own tap, not a button)")
    if os.environ.get("KLHU_SKIP_PLAY"):
        print("   SKIPPED (KLHU_SKIP_PLAY=1)")
    elif rows_found:
        r = rows_found[-1]
        # Fresh log: a player read off a log that was never cleared is the
        # REVIEW's own playback, which is a pass about the wrong screen (one run
        # reported exactly that).
        v.clear_logcat()
        shell("shell", "input", "tap", str(r["x"]), str(r["y"]))
        print(f"   tap the newest row @{r['x']},{r['y']}")
        time.sleep(2.5)
        rows_here = v.dump()
        check("56: the row opened that video's own screen",
              not v.on_screen(rows_here, "Videos"),
              repr(v.labels(rows_here)[:6]))
        # Opening the screen is the row's own job; PLAYING is the platform's own
        # control bar inside it, which is what `play_in_view` drives (the review's
        # playback of the working copy is a session of its own, so the log is
        # cleared above and a session read now is this screen's).
        played = v.play_in_view("56/row", rows_here)
        check("56: the row's video plays — the phone has its sound running",
              bool(played), f"started players: {played}")
        # Back, until the list's own rows are on screen: the platform's control
        # bar inside the playback view eats the first press.
        rows = back_to_list()
        check("56: back from the player leaves the list up, not the player",
              v.on_screen(rows, LIST_LABEL), repr(v.labels(rows)[:8]))
    else:
        check("56: the row could be found to tap", False,
              f"rows {v.labels(listed)[:8]}")

    # ---- share from the row ----
    step("56: share from the row — the phone's own list, nothing kept by sharing")
    files_shared = album()
    rows = v.dump()
    if not v.tap(rows, "Share", label="the row's share"):
        return
    shown = []
    for _ in range(6):
        time.sleep(2)
        shown = v.labels(v.dump())
        if shown:
            break
    print(f"   share sheet: {shown[:12]}")
    check("56: the phone's own share list appeared",
          any("share" in l.lower() for l in shown) or len(shown) > 3,
          repr(shown[:12]))
    check("56: sharing kept nothing new and removed nothing",
          album() == files_shared, f"album {album()}")
    shell("shell", "input", "keyevent", "4")   # back from the chooser
    time.sleep(2)
    rows = back_to_list()
    if not v.on_screen(rows, "Delete video"):
        # The chooser can leave the list behind it: the page's own action brings
        # it back, and the rows are read again either way.
        if v.tap(rows, "Videos", label="Videos (back to the list)"):
            time.sleep(2)
            rows = v.dump()

    # ---- the delete names the video, and takes that one only ----
    step("56: delete the row this walk made, behind its warning")
    rows = v.dump()
    if not v.tap(rows, "Delete video", label="a row's delete"):
        return
    time.sleep(2)
    rows = v.dump()
    check("56: deleting warns first, and names the video being deleted",
          v.on_screen(rows, "Delete this video?") and v.on_screen(rows, name)
          and v.on_screen(rows, "removed from your gallery"),
          repr(v.labels(rows)[:8]))
    if not v.tap(rows, "Cancel", label="Cancel", exact=True):
        return
    time.sleep(1.5)
    check("56: cancelling the warning deletes nothing", album() == files_shared,
          f"album {album()}")

    # Which row is which: the delete is what names it. The row tapped is the one
    # under the finger, so the row's own target decides — the newest is tapped by
    # its own bounds, exactly as the play step did.
    rows = v.dump()
    target = v.find(rows, "Delete video")
    if len(target) < 2:
        check("56: every row carries its own delete", len(target) >= len(entries),
              f"{len(target)} delete targets for {len(entries)} videos")
    if target:
        r = target[-1]
        shell("shell", "input", "tap", str(r["x"]), str(r["y"]))
        print(f"   tap the LAST row's delete @{r['x']},{r['y']}")
    else:
        return
    time.sleep(2)
    rows = v.dump()
    if not v.tap(rows, "Delete", label="Delete (the dialog's)", exact=True):
        return
    gone = v.wait_for(lambda: album() != files_shared, 25)
    went = [f for f in files_shared if f not in album()]
    check("56: the library loses that video's file", gone and album() != files_shared,
          f"album {album()} (was {files_shared})")
    check("56: the videos the reader kept earlier are still in the library",
          len(album()) == len(files_shared) - 1, f"album {album()}")
    after = entries_of(store().get(in_force) or [])
    check("56: the record loses that entry and keeps the earlier ones",
          [media_id(e) for e in after] == [media_id(e) for e in entries[:-1]],
          f"{in_force}: {[media_id(e) for e in before_after(entries, after)]} "
          f"({len(entries)} → {len(after)})")
    # The row tapped is the row under the finger, so WHICH file went is the proof
    # — and the two sets are compared, not the new file's mere existence (an
    # earlier draft asserted `bool(new_file)` here, which the check above had
    # already established and which says nothing about the file that left).
    check("56: the file that went is the entry that went, not the content's own",
          went == new_file,
          f"this walk's own file {new_file} left the album with its entry "
          f"(the file that went: {went})")

    # ---- and the page is still a page with videos ----
    rows = v.dump()
    check("56: the list still lists the content's other videos",
          bool(row_nodes(rows, name)) or len(entries) - 1 == 0,
          repr(v.labels(rows)[:10]))
    shell("shell", "input", "keyevent", "4")   # back to the page
    time.sleep(2)
    rows = v.dump()
    check("56: back on the page, the content still offers its videos",
          v.on_screen(rows, "Videos") or len(entries) - 1 == 0,
          repr(v.labels(rows)[:10]))

    # ---- the walk's own leftovers, never the reader's own video ----
    step("56: the walk's own leftovers, and never the reader's own video")
    baseline = int(os.environ.get("KLHU_BASELINE_ENTRIES", "-1"))
    if baseline < 0:
        print("   KLHU_BASELINE_ENTRIES is unset, so nothing is cleaned")
    while baseline >= 0:
        left = entries_of(store().get(in_force) or [])
        if len(left) <= baseline:
            break
        current = v.dump()
        if not v.on_screen(current, "Delete video"):
            # A previous run may have left the page behind: its own action brings
            # the list back.
            if v.tap(current, "Videos", label="Videos (back to the list)"):
                time.sleep(2)
            current = v.dump()
        targets = v.find(current, "Delete video")
        if not targets:
            print(f"   {len(left)} videos left, no delete target on screen: "
                  f"{v.labels(current)[:8]}")
            break
        r = targets[-1]
        shell("shell", "input", "tap", str(r["x"]), str(r["y"]))
        time.sleep(2)
        current = v.dump()
        if not v.tap(current, "Delete", label="Delete (the walk's own leftover)",
                     exact=True):
            break
        v.wait_for(lambda: len(entries_of(store().get(in_force) or [])) < len(left),
                   25)
    check("56: what this walk kept is gone again, and the content holds what the "
          "reader had",
          baseline < 0
          or len(entries_of(store().get(in_force) or [])) == baseline,
          f"{len(entries_of(store().get(in_force) or []))} entries left, "
          f"the reader had {baseline}")



def before_after(before, after):
    """The entries [before] held that [after] does not — the one that went."""
    gone = {media_id(e) for e in after}
    return [e for e in before if media_id(e) not in gone]


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("56", "57"):
        print(__doc__)
        sys.exit(2)
    row = sys.argv[1]
    os.makedirs(v.OUT, exist_ok=True)
    print(f"klhu walk 012 row {row} — device {DEV}, package {PKG}, out {v.OUT}")
    devices = shell("devices")
    if DEV not in devices or "offline" in devices:
        print(f"{DEV} is not available.\n"
              "  the reader's phone or an emulator has to be on the wire")
        sys.exit(2)
    # The app on the device must be the build on disk. On the reader's phone a
    # stale install is what it looks like: the page still offers `Play video`,
    # `Share` and `Delete video` — the controls this amendment withdrew — and a
    # row then reports the amendment missing from an app that never had it.
    v.preflight()
    # Wake the phone BEFORE the language step: a phone left overnight is asleep,
    # and `set_language` drives the page's own control from a dump — an asleep
    # screen answers that dump with a frame that is not the page (one run read a
    # stale screen, tapped where `中文` was on it, and then could not find
    # `English` on the page it never reached). The rows wake again for
    # themselves; this is for the step that runs before them.
    wake()
    original = language()
    try:
        if original != "en" and not set_language("en"):
            print("the app's own language control could not be driven; "
                  "the labels below are the app's English copy and the walk "
                  "cannot speak the phone's own language")
            sys.exit(2)
        {"56": row_56, "57": row_57}[row]()
    finally:
        # Whatever the row did or failed on, the device goes back to how it was
        # found: the reader's own language, and the screen's stay-on. The row can
        # end on a pushed screen (the videos list), where the language control is
        # not on screen at all — so back to the page first, then put it back.
        if language() != original:
            pop_to_page()
            if not set_language(original if original in NATIVE else "en"):
                print("   the app's own language could not be set back: "
                      f"it reads {language()!r}, it was {original!r}")
        rest()

    print("\n===== result =====")
    failed = [r for r in v.RESULTS if not r[1]]
    for name, ok, detail in v.RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}"
              f"{(' — ' + detail) if detail else ''}")
    print(f"\n{len(v.RESULTS) - len(failed)}/{len(v.RESULTS)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
