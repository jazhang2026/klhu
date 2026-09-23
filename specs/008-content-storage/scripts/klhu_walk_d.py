#!/usr/bin/env python3
"""Walk part d — the destructive tail of the 008 quickstart:

  SC8 (pre-set variant): delete a shipped pre-set, confirm, restart -> it stays
      gone (tombstone) while the other pre-sets and user content survive.
  SC11: a text file removed behind the app's back -> that row is marked damaged
      and stays deletable; the rest of the library is usable.
  SC10: garbage written into index.json -> the app starts, the pre-sets are
      re-seeded, the bad file is moved aside as index.corrupt-*.json and the
      repair is REPORTED on screen (FR-010, contract § Error and repair states).

The library lives at app_flutter/content/ (path_provider's documents dir).
"""
import json
import os
import sys
import time

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from klhu_walk import (adb, dump, labels, show, tap, step, on_screen,   # noqa
                       open_list)

PKG = "com.example.klhu"
LIB = "app_flutter/content"


def restart():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(6)
    return dump()


def names(rows):
    return [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]]


def sheets():
    """(name, language) per row of the content list."""
    rows = dump()
    out = []
    for r in rows:
        d = r["desc"] or ""
        if "\n" in d:
            n, lang = d.split("\n", 1)
            out.append((n, lang.split(" ·")[0], r))
    return out


def tap_delete_beside(row):
    rows = dump()
    cands = [r for r in rows if r["desc"] == "Delete"
             and abs(r["y"] - row["y"]) < 120]
    if not cands:
        print("   no Delete icon beside that row")
        return False
    adb("shell", "input", "tap", str(cands[0]["x"]), str(cands[0]["y"]))
    print(f"   tap Delete beside {row['desc'].splitlines()[0]!r}")
    return True


def confirm_dialog(expect_phrase=None):
    rows = dump()
    d = [r["desc"] or r["text"] for r in rows]
    body = [x for x in d if "undone" in x or "reinstall" in x]
    print("   dialog body:", body)
    if expect_phrase is not None:
        print(f"   dialog mentions {expect_phrase!r}:",
              any(expect_phrase in x for x in d))
    delete_btns = [r for r in rows if r["desc"] == "Delete" and r["y"] < 1600]
    if not delete_btns:
        print("   no confirm button found")
        return False
    r = delete_btns[-1]
    adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
    print(f"   confirm Delete @{r['x']},{r['y']}")
    time.sleep(2.5)
    return True


step("SC8/pre-set: delete the ENGLISH pre-set (warning variant)")
rows = open_list()
target = None
for name, lang, r in sheets():
    if name.startswith("The sun rose"):
        target = r
        break
print("   rows:", [(n, l) for n, l, _ in sheets()])
if target is None:
    print("   English pre-set not in the list — aborting this step")
else:
    tap_delete_beside(target)
    time.sleep(2)
    confirm_dialog("reinstall")

step("SC8/pre-set: the library after the delete, and after a restart")
rows = open_list()
print("   entries:", names(rows))
rows = restart()
rows = open_list()
after = names(rows)
print("   after restart:", after)
print("   deleted pre-set stayed gone:",
      not any(n.startswith("The sun rose") for n in after))
print("   other pre-sets survived:",
      any(n.startswith("El sol") for n in after),
      any(n.startswith("\u6e05\u6668") for n in after))

step("SC11: remove a user entry's text file behind the app's back")
idx = adb("shell", "run-as", PKG, "cat", f"{LIB}/index.json").stdout
data = json.loads(idx)
user = [e for e in data["entries"] if e["origin"] == "user"]
print("   user entries in the index:", [(e["id"], e["name"]) for e in user])
print("   text files:",
      adb("shell", "run-as", PKG, "ls", f"{LIB}/contents").stdout.split())
if user:
    victim = user[0]
    print("   rm", adb("shell", "run-as", PKG, "rm",
                       f"{LIB}/contents/{victim['id']}.txt").stdout or "(no output)")
    rows = restart()
    rows = open_list()
    show(rows, 12)
    print("   damaged row present:",
          any("damaged" in (r["desc"] or "") for r in rows))

step("SC10: garbage in index.json -> repair + report on launch")
print("   writing garbage:",
      adb("shell", "run-as", PKG, "sh", "-c",
          f"'echo notjson > {LIB}/index.json'").stdout or "(ok)")
rows = restart()
print("   page after relaunch:", [d for d in labels(rows) if len(d) > 30][:1])
print("   REPAIR MESSAGE:", [d for d in labels(rows)
                             if "repaired" in d or "repair" in d])
rows = open_list()
print("   entries after the repair:", names(rows))
print("   moved-aside indexes:",
      [f for f in adb("shell", "run-as", PKG, "ls", LIB).stdout.split()
       if "corrupt" in f])
