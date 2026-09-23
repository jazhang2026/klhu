#!/usr/bin/env python3
"""Walk part c: SC12 (unsaved-changes guard, clean redo), SC8 (delete with a
warning, cancel vs confirm, pre-set tombstone across a restart), SC11 (damaged
entry), SC10 (a corrupt index is moved aside and the app still starts).

Destructive by design — it runs last. Every observation is printed with its
evidence line, and the whole run is also written to klhu_walk_c.log.
"""
import re
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


def names(rows):
    return [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]]


def body(rows):
    return " ".join(d for d in labels(rows) if len(d) > 60)


def tap_row(rows, needle, exclude="(2)", label=None):
    for r in rows:
        name = r["desc"] or r["text"]
        if needle in name and (exclude is None or exclude not in name):
            adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
            print(f"   tap row {label or needle!r} @{r['x']},{r['y']}")
            return True
    print(f"   NOT FOUND row {needle!r}: {labels(rows)[:6]}")
    return False


def tap_delete_on(rows, needle, exclude="(2)"):
    """The trailing icon of a specific row: the Delete button in the same
    vertical band as that row."""
    row = None
    for r in rows:
        name = r["desc"] or r["text"]
        if needle in name and (exclude is None or exclude not in name):
            row = r
            break
    if row is None:
        print(f"   NOT FOUND row {needle!r}")
        return False
    cands = [r for r in rows if r["desc"] == "Delete"
             and abs(r["y"] - row["y"]) < 120]
    if not cands:
        print("   no Delete icon in that row's band")
        return False
    adb("shell", "input", "tap", str(cands[0]["x"]), str(cands[0]["y"]))
    print(f"   tap Delete of {row['desc'].splitlines()[0]!r} "
          f"@{cands[0]['x']},{cands[0]['y']}")
    return True


def in_edit(rows):
    return on_screen(rows, "Done") and on_screen(rows, "Undo")


step("SC12: restart, dirty a USER entry, then switch content")
rows = restart()
print("   opened onto:", [d for d in labels(rows) if d.startswith("Reading:")])
rows = open_list()
tap_row(rows, "MyReadingNotes", exclude=None)
time.sleep(2.5)
rows = dump()
print("   page:", [d for d in labels(rows) if d.startswith("Reading:")])
if on_screen(rows, "Stop"):
    tap(rows, "Stop", exact=True)
    time.sleep(1.2)
    rows = dump()
tap(rows, "Edit", exact=True)
time.sleep(1.5)
adb("shell", "input", "tap", *FIRST_CHAR)
time.sleep(1.2)
type_text("DIRTY")
time.sleep(1.2)
rows = dump()
print("   in EDIT:", in_edit(rows))
rows = open_list()
print("   pick a different entry while dirty:")
tap_row(rows, "The sun rose")
time.sleep(2.5)
rows = dump()
show(rows, 8)
d = labels(rows)
print("   GUARD DIALOG visible:", any("Unsaved" in x or "not saved" in x
                                      for x in d))
print("   dialog text:", [x for x in d if "new" in x.lower() or
                           "Discard" in x or "Cancel" in x or "save" in x])

step("SC12: Cancel keeps the edit; the switch does not happen")
if on_screen(rows, "Cancel"):
    tap(rows, "Cancel", exact=True)
    time.sleep(2)
    rows = dump()
    print("   still on the dirty content:", "DIRTY" in body(rows))
    print("   English content NOT loaded:",
          "over the quiet town" not in body(rows))

step("SC12: Discard drops the edit and loads the chosen content")
rows = open_list()
tap_row(rows, "The sun rose")
time.sleep(2.5)
rows = dump()
if on_screen(rows, "Discard"):
    tap(rows, "Discard", exact=True)
    time.sleep(2.5)
    rows = dump()
    print("   after Discard:", [x for x in labels(rows)
                                 if x.startswith("Reading:")])
    print("   DIRTY gone:", "DIRTY" not in body(rows))
    print("   English content loaded:",
          "over the quiet town" in body(rows))
else:
    print("   no Discard button:", labels(rows)[:8])

step("SC8: delete a user entry — Cancel changes nothing")
rows = open_list()
before = names(rows)
print("   entries:", before)
tap_delete_on(rows, "MyReadingNotes", exclude=None)
time.sleep(2)
rows = dump()
d = labels(rows)
print("   dialog:", [x for x in d if "Delete" in x or "undone" in x or
                       "Cancel" in x])
tap(rows, "Cancel", exact=True)
time.sleep(2)
rows = dump()
print("   entry survives Cancel:",
      "MyReadingNotes" in " ".join(names(rows)))

step("SC8: delete again and confirm — the entry goes")
rows = dump()
tap_delete_on(rows, "MyReadingNotes", exclude=None)
time.sleep(2)
rows = dump()
btns = [r for r in rows if r["desc"] == "Delete" and r["x"] < 500]
print("   confirm buttons:", [(r["desc"], r["x"], r["y"]) for r in rows
                              if r["desc"] in ("Delete", "Cancel")])
# The dialog's confirm button is the one inside the dialog (right-hand side).
cand = [r for r in rows if r["desc"] == "Delete" and r["y"] < 1500]
if cand:
    r = cand[-1]
    adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
    print(f"   confirm Delete @{r['x']},{r['y']}")
time.sleep(2.5)
rows = dump()
print("   entries now:", names(rows) if "Contents" in labels(rows)[:3]
      else "(not in the list)")
rows = open_list()
after = names(rows)
print("   entries:", after)
print("   MyReadingNotes deleted:", "MyReadingNotes" not in after)

step("SC8: delete a PRE-SET (warning variant), confirm, restart")
rows = dump()
tap_delete_on(rows, "清晨的阳光", exclude=None)
time.sleep(2)
rows = dump()
d = labels(rows)
print("   pre-set dialog:", [x for x in d if "reinstall" in x or
                             "undone" in x or "Delete this" in x])
cand = [r for r in rows if r["desc"] == "Delete" and r["y"] < 1500]
if cand:
    r = cand[-1]
    adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
    print(f"   confirm Delete @{r['x']},{r['y']}")
time.sleep(2.5)
rows = open_list()
print("   entries now:", names(rows))
rows = restart()
rows = open_list()
after_restart = names(rows)
print("   after a restart:", after_restart)
print("   the deleted pre-set stayed gone:",
      not any("清晨" in n for n in after_restart))
print("   the other pre-sets are still there:",
      any("The sun rose" in n for n in after_restart),
      any("El sol" in n for n in after_restart))
