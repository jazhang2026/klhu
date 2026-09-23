#!/usr/bin/env python3
"""Walk part b, state-driven: SC12 (unsaved-changes guard), SC3 (auto-named
save), SC6 (update in place).

Rules learned on-device:
  * EDIT mode shows Undo / Save / Done in the bottom row — Save writes to the
    library, Done only commits the text into the view. Never tap Save while not
    in EDIT (it is not there, and the tap lands on whatever moved into its
    place).
  * `adb input text` inserts AT THE CARET: the caret is placed by tapping the
    text's first character; Ctrl+A / MOVE_HOME / MOVE_END do nothing in this
    TextField.
"""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from klhu_walk import (adb, dump, labels, show, tap, type_text, key, step,  # noqa
                       on_screen, open_list, app_pid)

PKG = "com.example.klhu"
FIRST_CHAR = ("60", "400")


def restart():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(6)
    return dump()


def caret_home():
    adb("shell", "input", "tap", *FIRST_CHAR)
    time.sleep(1.0)


def in_edit(rows):
    return on_screen(rows, "Done") and on_screen(rows, "Undo")


def tap_row(rows, needle, exclude="(2)", label=None):
    for r in rows:
        name = r["desc"] or r["text"]
        if needle in name and (exclude is None or exclude not in name):
            adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
            print(f"   tap row {label or needle!r} @{r['x']},{r['y']}")
            return True
    print(f"   NOT FOUND row {needle!r}: {labels(rows)[:6]}")
    return False


def names(rows):
    return [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]]


def body_text(rows):
    return " ".join(d for d in labels(rows) if len(d) > 80)


def enter_edit():
    rows = dump()
    if on_screen(rows, "Stop"):
        tap(rows, "Stop", exact=True)
        time.sleep(1.2)
        rows = dump()
    assert tap(rows, "Edit", exact=True), "no Edit button on screen"
    time.sleep(1.5)
    rows = dump()
    assert in_edit(rows), f"not in EDIT: {labels(rows)}"
    return rows


step("SC12: restart clean, then edit WITHOUT saving and switch content")
rows = restart()
print("   opened onto:", [d for d in labels(rows) if d.startswith("Reading:")])
rows = enter_edit()
caret_home()
type_text("UNSAVEDMARK")
time.sleep(1.0)
rows = dump()
print("   text committed into the view? (still EDIT): ", in_edit(rows))
rows = open_list()
show(rows, 6)
found = False
for r in rows:
    if "The sun rose" in (r["desc"] or ""):
        adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
        found = True
        break
print("   picked another content:", found)
time.sleep(2.5)
rows = dump()
show(rows, 8)
d = [r["desc"] or r["text"] for r in rows]
print("   GUARD DIALOG:", [x for x in d if any(
    w in x for w in ("Unsaved", "not saved", "Discard", "Cancel"))])
print("   import re; discarding now")
if on_screen(rows, "Discard"):
    tap(rows, "Discard", exact=True)
    time.sleep(2.5)
    rows = dump()
    print("   after Discard:", [x for x in labels(rows) if x.startswith(
        "Reading:")])
    print("   UNSAVEDMARK gone:", "UNSAVEDMARK" not in body_text(rows))

step("SC3: edit the SPANISH pre-set, new first line, SAVE (library write)")
rows = open_list()
tap_row(rows, "El sol salió")
time.sleep(2.5)
rows = enter_edit()
caret_home()
type_text("MyReadingNotes")
time.sleep(0.6)
key(66)
time.sleep(0.8)
rows = dump()
print("   still in EDIT:", in_edit(rows))
tap(rows, "Save", exact=True)
time.sleep(2.5)
rows = dump()
print("   after Save:", labels(rows)[:8])
print("   edit still on screen (Saved keeps the text):",
      "MyReadingNotes" in body_text(rows))

step("SC3: the library gained exactly one entry, named from the first line")
rows = open_list()
show(rows, 12)
n = names(rows)
print("   entries:", len(n), n)
print("   FR-008 name is 'MyReadingNotes':", n[0] == "MyReadingNotes")

step("SC7/SC-010: the untouched original still opens as shipped")
rows = open_list()
tap_row(rows, "El sol salió")
time.sleep(2.5)
rows = dump()
body = body_text(rows)
print("   original free of the edit:", "MyReadingNotes" not in body)
print("   and still the shipped line:",
      "El sol salió sobre el pueblo tranquilo" in body)

step("SC6: reload the new entry and Save again — same entry, no duplicate")
rows = open_list()
tap_row(rows, "MyReadingNotes", exclude=None)
time.sleep(2.5)
rows = dump()
print("   page:", [x for x in labels(rows) if x.startswith("Reading:")])
rows = enter_edit()
caret_home()
type_text("Rev")
time.sleep(0.8)
tap(dump(), "Save", exact=True)
time.sleep(2.5)
rows = open_list()
show(rows, 12)
n2 = names(rows)
print("   entries after the second save:", len(n2), n2)
print("   updated in place (same count, renamed):",
      len(n2) == len(n), n2[0] if n2 else None)
