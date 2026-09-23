#!/usr/bin/env python3
"""SC5 on device: EDIT offers Undo, one Undo reverts exactly one edit, the
control goes disabled when the history is exhausted, and the final undo
surfaces the localized message."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from klhu_walk import (adb, dump, labels, show, tap, type_text, step,
                       open_list, on_screen)  # noqa

PKG = "com.example.klhu"


def restart():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(6)
    return dump()


def body(rows):
    return " ".join(d for d in labels(rows) if len(d) > 60)


def undo_state(rows):
    return [(r["desc"], r["enabled"]) for r in rows if r["desc"] == "Undo"]


def enter_edit(rows):
    if on_screen(rows, "Stop"):
        tap(rows, "Stop", exact=True)
        time.sleep(1.2)
        rows = dump()
    tap(rows, "Edit", exact=True)
    time.sleep(1.5)
    return dump()


step("SC5: open a pre-set and start EDIT (Undo starts disabled)")
restart()
rows = open_list()
adb("shell", "input", "tap", "540", "377")     # first row (newest)
time.sleep(2.5)
rows = dump()
print("   page:", [d for d in labels(rows) if d.startswith("Reading:")])
rows = enter_edit(rows)
show(rows, 8)
print("   Undo right after entering EDIT:", undo_state(rows))

step("SC5: type at the caret (end of the text), then ONE Undo")
# _loadEntry puts the caret at the end of the text, so plain typing appends.
type_text("MARKER")
time.sleep(1.2)
rows = dump()
print("   Undo now enabled:", undo_state(rows))
tap(rows, "Undo", exact=True)
time.sleep(1.5)
rows = dump()
print("   Undo after one step:", undo_state(rows))
tap(rows, "Done", exact=True)
time.sleep(2)
rows = dump()
print("   one undo reverted the edit:", "MARKER" not in body(rows))

step("SC5: two edits, then undo until the button disables itself")
rows = enter_edit(rows)
type_text("AAA")
time.sleep(1.0)
type_text("BBB")
time.sleep(1.2)
rows = dump()
print("   Undo state with history:", undo_state(rows))
seen_message = None
for i in range(6):
    rows = dump()
    state = undo_state(rows)
    msg = [d for d in labels(rows) if "undo" in d.lower() or "Nothing" in d]
    if msg:
        seen_message = msg
    print(f"   round {i}: Undo {state} {msg}")
    if state and state[0][1] is False:
        break
    tap(rows, "Undo", exact=True)
    time.sleep(1.5)
rows = dump()
print("   final Undo state:", undo_state(rows))
print("   exhaustion message seen:", seen_message)
