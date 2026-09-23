#!/usr/bin/env python3
"""klhu device walk — 008 quickstart, shared helpers.

Every step re-dumps and taps the dump's own bounds centre; logcat is cleared
before each read so an engine-locale claim can only come from that read.

Usage:  python3 klhu_walk.py <part>   (part = a|b|c)
"""
import re
import subprocess
import sys
import time

DEV = "emulator-5554"
PKG = "com.example.klhu"
XML = "/sdcard/klhu_walk.xml"
LOCAL = "/tmp/klhu_walk.xml"


def adb(*args, **kw):
    return subprocess.run(["adb", "-s", DEV, *args], capture_output=True,
                          text=True, **kw)


def dump(retries=3):
    """Fresh dump, into a file deleted first so a failed pull cannot be read
    as a successful one."""
    for _ in range(retries):
        subprocess.run(["rm", "-f", LOCAL])
        adb("shell", "uiautomator", "dump", XML)
        adb("pull", XML, LOCAL)
        try:
            xml = open(LOCAL, encoding="utf-8").read()
        except OSError:
            time.sleep(1)
            continue
        rows = []
        for m in re.finditer(r"<node[^>]*>", xml):
            tag = m.group(0)

            def attr(k):
                a = re.search(k + r'="([^"]*)"', tag)
                return a.group(1) if a else ""

            desc, bounds = attr("content-desc"), attr("bounds")
            if not desc or not bounds:
                continue
            n = [int(x) for x in re.findall(r"\d+", bounds)]
            rows.append({
                "desc": desc.replace("&#10;", "\n"),
                "text": attr("text"),
                "enabled": attr("enabled") != "false",
                "x": (n[0] + n[2]) // 2,
                "y": (n[1] + n[3]) // 2,
            })
        return rows
    print("DUMP FAILED")
    sys.exit(2)


def labels(rows):
    return [r["desc"] or r["text"] for r in rows]


def show(rows, limit=12):
    for r in rows[:limit]:
        print(f"   [{r['x']:>4},{r['y']:>4}]"
              f"{'' if r['enabled'] else ' (disabled)'} "
              f"{(r['desc'] or r['text'])!r}")


def tap(rows, needle, label=None, exact=False):
    for r in rows:
        name = r["desc"] or r["text"]
        if (name == needle) if exact else (needle in name):
            adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
            print(f"   tap {label or needle!r} @{r['x']},{r['y']}")
            return True
    print(f"   NOT FOUND: {needle!r} — visible: {labels(rows)[:10]}")
    return False


def type_text(s):
    adb("shell", "input", "text", s)


def key(code):
    adb("shell", "input", "keyevent", str(code))


def on_screen(rows, needle):
    return any(needle in (r["desc"] or r["text"]) for r in rows)


def step(title):
    print(f"\n===== {title} =====")


def engine_trace(marker, since=None):
    print(f"-- engine locale trace ({marker}) --")
    log = adb("logcat", "-d", "-v", "time").stdout
    for line in log.splitlines():
        if since and line[0:18] < since:
            continue
        if any(k in line for k in ("Synthesis request", "default lang",
                                   "Utterance ID has started",
                                   "Utterance ID has completed")):
            print("   ", line.strip())


def now_stamp():
    return adb("shell", "date", "+%m-%d %H:%M:%S.%3N").stdout.strip()


def app_pid():
    return adb("shell", "pidof", PKG).stdout.strip()


def ensure_stopped():
    rows = dump()
    for name in ("Stop", "停止"):
        if on_screen(rows, name):
            tap(rows, name)
            time.sleep(1)
            return True
    return False


def open_list():
    rows = dump()
    tap(rows, "Contents")
    time.sleep(2.5)
    return dump()


def follow(part):
    if part == "a":
        scenario_3_and_4()
    else:
        print("unknown part (the later scenarios live in klhu_walk_*.py)")
        sys.exit(2)


# --------------------------------------------------------------------------
def scenario_3_and_4():
    step("SC3 setup: stop any read, enter EDIT on the current content")
    ensure_stopped()
    rows = dump()
    tap(rows, "Edit")
    time.sleep(1.5)
    rows = dump()
    show(rows)
    print("   EDIT offers Save/Undo:", on_screen(rows, "Save"),
          on_screen(rows, "Undo"))

    step("SC3: cursor home, a distinctive first line, Enter, Save")
    key(122)          # KEYCODE_MOVE_HOME
    time.sleep(0.5)
    type_text("MyReadingNotes")
    time.sleep(0.5)
    key(66)           # KEYCODE_ENTER — first line is now MyReadingNotes
    time.sleep(0.8)
    rows = dump()
    print("   content now:", [r["desc"] or r["text"] for r in rows if "Notes"
                              in (r["desc"] or r["text"]) or
                              "清晨" in (r["desc"] or r["text"])][:2])
    tap(rows, "Save")
    time.sleep(2)
    rows = dump()
    print("   after Save, snackbar/state:", labels(rows)[:8])

    step("SC3: the list holds an entry named MyReadingNotes")
    rows = open_list()
    show(rows)
    print("   name is exactly MyReadingNotes:",
          any((r["desc"] or r["text"]).startswith("MyReadingNotes\n")
              or (r["desc"] or r["text"]) == "MyReadingNotes" for r in rows))

    step("SC4: reopen it and check the text came back byte-identical")
    for r in rows:
        if (r["desc"] or r["text"]).startswith("MyReadingNotes"):
            adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
            print(f"   tap row @{r['x']},{r['y']}")
            break
    time.sleep(2.5)
    rows = dump()
    body = [r["desc"] or r["text"] for r in rows]
    print("   page shows the new text:",
          any(d.startswith("MyReadingNotes") and "清晨" in d for d in body))
    print("   caption:", [d for d in body if d.startswith("Reading:")])

    step("SC4: force-stop, relaunch — library and last-opened survive")
    before = app_pid()
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1.5)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(6)
    rows = dump()
    print(f"   pid {before} -> {app_pid()}")
    body = [r["desc"] or r["text"] for r in rows]
    print("   reopened onto the last content:",
          [d for d in body if d.startswith("Reading:")])
    rows = open_list()
    show(rows)
    print("   entries after restart:",
          [r["desc"].split("\n")[0] for r in rows if "\n" in r["desc"]])


if __name__ == "__main__":
    follow(sys.argv[1] if len(sys.argv) > 1 else "a")
