#!/usr/bin/env python3
"""SC8, pre-set variant, redone: delete a shipped pre-set, confirm, restart —
the tombstone keeps it gone; a fresh install (pm clear == wiped data) brings it
back, which is what the dialog promises."""
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from klhu_walk import adb, dump, labels, show, tap, step, open_list  # noqa

PKG = "com.example.klhu"


def restart():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(6)
    return dump()


def names(rows):
    return [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]]


step("SC8/pre-set: make sure the app is up and the list is open")
restart()
rows = open_list()
show(rows, 10)
print("   entries:", names(rows))

step("SC8/pre-set: tap the trailing Delete of the English pre-set")
row = next(r for r in rows if (r["desc"] or "").startswith("The sun rose"))
icons = [r for r in rows if r["desc"] == "Delete" and abs(r["y"] - row["y"]) < 120]
print("   row:", repr(row["desc"]), "delete icon:", icons[0] if icons else None)
adb("shell", "input", "tap", str(icons[0]["x"]), str(icons[0]["y"]))
time.sleep(2.5)

step("SC8/pre-set: the dialog states the reinstall consequence")
rows = dump()
show(rows, 8)
text = [r["desc"] or r["text"] for r in rows]
print("   title:", [t for t in text if "Delete this" in t])
print("   body:", [t for t in text if "undone" in t or "reinstall" in t])
print("   'reinstall' promised:", any("reinstall" in t for t in text))

step("SC8/pre-set: cancel keeps it, then delete for real")
cancel = [r for r in rows if r["desc"] == "Cancel"]
if cancel:
    adb("shell", "input", "tap", str(cancel[0]["x"]), str(cancel[0]["y"]))
    time.sleep(2)
    rows = dump()
    print("   after Cancel, still listed:",
          any((r["desc"] or "").startswith("The sun rose") for r in rows))

rows = dump()
icons = [r for r in rows if r["desc"] == "Delete"
         and abs(r["y"] - row["y"]) < 120]
if not icons:
    rows = open_list()
    icons = [r for r in rows if r["desc"] == "Delete"
             and abs(r["y"] - row["y"]) < 120]
adb("shell", "input", "tap", str(icons[0]["x"]), str(icons[0]["y"]))
time.sleep(2.5)
rows = dump()
confirm = [r for r in rows if r["desc"] == "Delete" and r["y"] < 1600]
adb("shell", "input", "tap", str(confirm[-1]["x"]), str(confirm[-1]["y"]))
print("   confirmed Delete")
time.sleep(3)

step("SC8/pre-set: gone now, and still gone after a restart")
rows = restart()
rows = open_list()
after = names(rows)
print("   after restart:", after)
print("   tombstone held:", not any(n.startswith("The sun rose") for n in after))
print("   remaining pre-sets:",
      [n for n in after if n.startswith(("El sol", "\u6e05\u6668"))])
tomb = adb("shell", "run-as", PKG, "cat", "app_flutter/content/index.json").stdout
print("   deletedPresetIds in the index:",
      [l for l in tomb.split(",") if "preset_en_sample" in l][:2])

step("SC8/pre-set: a fresh install brings it back (the dialog's promise)")
adb("shell", "pm", "clear", PKG)
time.sleep(1)
restart()
rows = open_list()
back = names(rows)
print("   after a wiped-data launch:", back)
print("   the deleted pre-set is back:",
      any(n.startswith("The sun rose") for n in back))
