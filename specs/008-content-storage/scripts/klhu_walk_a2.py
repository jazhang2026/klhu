#!/usr/bin/env python3
"""Walk part a2: SC3/FR-008 auto-naming via Ctrl+A, SC6 update-in-place,
SC7 edit a pre-set -> new user entry with the original intact."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from klhu_walk import (adb, dump, labels, show, tap, type_text, key, step,   # noqa: E402
                       on_screen, ensure_stopped, open_list)


def focus_field():
    """Tap the content area so the TextField owns the caret (keys go nowhere
    otherwise — the first attempt typed into the void)."""
    adb("shell", "input", "tap", "540", "700")
    time.sleep(1)


def select_all():
    # KEYCODE_CTRL_LEFT + KEYCODE_A (113/29)
    adb("shell", "input", "keycombination", "113", "29")
    time.sleep(0.8)


step("SC6/FR-008: replace the first line of the loaded user entry, Save")
ensure_stopped()
rows = dump()
before_names = [r["desc"].split("\n")[0] for r in rows]
tap(rows, "Edit")
time.sleep(1.5)
focus_field()
select_all()
type_text("MyReadingNotes")
time.sleep(0.6)
key(66)                      # newline: the first line ends here
time.sleep(0.6)
rows = dump()
tap(rows, "Save")
time.sleep(2.5)
rows = dump()
print("   after Save:", labels(rows)[:8])

rows = open_list()
show(rows)
names = [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]]
print("   entries now:", len(names), names)
print("   the SAME entry was renamed (no duplicate):",
      len(names) == 4 and names[0] == "MyReadingNotes")

step("SC7: edit the Spanish pre-set and save")
tap(rows, "Back")
time.sleep(1.5)
rows = open_list()
for r in rows:
    if r["desc"].startswith("El sol salió"):
        adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
        break
time.sleep(2.5)
rows = dump()
spanish_before = [d for d in labels(rows) if "El sol" in d]
print("   page:", spanish_before[:1])
tap(rows, "Edit")
time.sleep(1.5)
focus_field()
key(123)                     # MOVE_END
type_text(" prueba")
time.sleep(0.8)
rows = dump()
tap(rows, "Save")
time.sleep(2.5)
rows = dump()
print("   after Save:", labels(rows)[:8])

step("SC7: the edit became a NEW entry; the original is untouched")
rows = open_list()
show(rows)
names = [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]]
print("   entries now:", len(names), names)
# reopen the ORIGINAL Spanish pre-set (the row without the edit) and check
rows = dump()
row = rows[4] if len(rows) > 4 else None
for r in rows:
    if r["desc"].startswith("El sol") and "(2)" not in r["desc"]:
        adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
        print(f"   reopen original @{r['x']},{r['y']}")
        break
time.sleep(2.5)
rows = dump()
body = " ".join(labels(rows))
print("   original still has no 'prueba':", "prueba" not in body)
print("   original text on screen:",
      [d for d in labels(rows) if d.startswith("El sol")][:1])
