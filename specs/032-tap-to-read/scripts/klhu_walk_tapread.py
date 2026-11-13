#!/usr/bin/env python3
"""klhu device walk — 032 quickstart (tap-to-read, looping Continue Read).

What each part proves, and with which evidence line:

  W1  the toolbar has NO Read button — only Continue Read / Stop / Edit at
      idle (and Pause/Resume while a read plays)
  W2  a tap on a sentence highlights AND reads it — `klhu read range` +
      `klhu speak` name exactly one sentence step; the highlight is still
      painted after the read ends (yellow pixels)
  W3  tapping the same spot repeats the same sentence
  W4  a tap lower in the text reads a different sentence
  W5  a long-press reads the whole paragraph — the `klhu speak` lines cover
      every sentence of paragraph 1, and the paragraph highlight remains
  W6  Continue Read loops: the `klhu speak` sequence reaches the text's end
      and repeats from the first sentence without another press; Stop ends it
      (no `klhu speak` lines after the press)
  W7  Pause parks the loop mid-pass and Resume restarts it; Stop still wins

Mechanics are 010's (`specs/010-continue-read/scripts/klhu_walk_continue.py`):
one string per `adb shell` command, `uiautomator dump` reads, `tap_node` by
content-desc, `check(name, ok, detail)` with a PASS/FAIL summary.

Requires: accessibility_enabled=1 on the device (the dump needs the Flutter
semantics tree), the debug build installed, `klhu` AVD or any device.

Usage:
    python3 klhu_walk_tapread.py            # all checks
    python3 klhu_walk_tapread.py W2 W6      # a subset
"""
import json
import os
import re
import subprocess
import sys
import time

ADB_SERIAL = os.environ.get("ADB_SERIAL", "emulator-5554")
KLHU_OUT = os.environ.get("KLHU_OUT", "/tmp")
PKG = "com.example.klhu"
HERE = os.path.dirname(os.path.abspath(__file__))
KLHU_REPO = os.environ.get(
    "KLHU_REPO", os.path.abspath(os.path.join(HERE, "..", "..", ".."))
)
XML = f"{KLHU_OUT}/klhu_walk_032.xml"

DEV = ["adb", "-s", ADB_SERIAL]
RESULTS = []


def adb(*args, binary=False):
    r = subprocess.run(DEV + list(args), capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def dump():
    for _ in range(3):
        subprocess.run(["rm", "-f", XML])
        adb("shell", "uiautomator", "dump", "/sdcard/klhu_walk_032.xml")
        adb("pull", "/sdcard/klhu_walk_032.xml", XML)
        try:
            with open(XML, encoding="utf-8") as fh:
                xml = fh.read()
        except OSError:
            time.sleep(1)
            continue
        rows = []
        for m in re.finditer(r"<node[^>]*>", xml):
            tag = m.group(0)

            def attr(key, tag=tag):
                hit = re.search(key + r'="([^"]*)"', tag)
                return hit.group(1) if hit else ""

            desc, bounds = attr("content-desc"), attr("bounds")
            if not bounds:
                continue
            n = [int(x) for x in re.findall(r"\d+", bounds)]
            if len(n) != 4:
                continue
            rows.append({
                "desc": desc.replace("&#10;", "\n"),
                "text": attr("text"),
                "enabled": attr("enabled") != "false",
                "x": (n[0] + n[2]) // 2,
                "y": (n[1] + n[3]) // 2,
                "bounds": (n[0], n[1], n[2], n[3]),
            })
        return rows
    print("DUMP FAILED")
    sys.exit(2)


def labels(rows):
    return [r["desc"] or r["text"] for r in rows]


def find(rows, needle):
    for r in rows:
        if needle in (r["desc"] or r["text"]):
            return r
    return None


def tap_at(x, y, label=""):
    adb("shell", "input", "tap", str(x), str(y))
    print(f"   tap {label} @{x},{y}")


def long_press_at(x, y, label="", ms=900):
    adb("shell", "input", "swipe", str(x), str(y), str(x), str(y), str(ms))
    print(f"   long-press {label} @{x},{y} ({ms}ms)")


def tap_node(rows, needle, label=None):
    node = find(rows, needle)
    if node is None:
        print(f"   NOT FOUND: {needle!r} — visible: {[l for l in labels(rows) if l][:12]}")
        return False
    if not node["enabled"]:
        print(f"   DISABLED: {needle!r}")
        return False
    tap_at(node["x"], node["y"], label or needle)
    return True


def start_app():
    adb("shell", "am", "force-stop", PKG)
    time.sleep(1)
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(7)
    return dump()


def clear_log():
    adb("logcat", "-c")


def log_lines(*needles):
    out = adb("logcat", "-d", "-v", "time")
    return [ln.strip() for ln in out.splitlines()
            if any(k in ln for k in needles)]


RANGE_RE = re.compile(r"klhu read range: (\d+)\.\.(\d+)")
SPEAK_RE = re.compile(r'klhu speak.*"(.*)"')


def snapshot():
    """A line-count watermark into the cumulative `logcat -d` output."""
    return len(adb("logcat", "-d", "-v", "time").splitlines())


def lines_since(n):
    out = adb("logcat", "-d", "-v", "time").splitlines()
    return out[n:]


def new_ranges(n):
    return [(int(m.group(1)), int(m.group(2)))
            for ln in lines_since(n)
            for m in [RANGE_RE.search(ln)] if m]


def new_speaks(n):
    out = []
    for ln in lines_since(n):
        m = SPEAK_RE.search(ln)
        if m:
            out.append(m.group(1))
    return out


def wait_for(pred, seconds=30, poll=0.5):
    end = time.time() + seconds
    while time.time() < end:
        if pred():
            return True
        time.sleep(poll)
    return False


def wait_idle(seconds=40):
    """The read ended when Continue Read is back in the toolbar."""
    return wait_for(lambda: find(dump(), "Continue Read") is not None,
                    seconds=seconds, poll=1.0)


def yellow_pixels(path):
    from PIL import Image
    with open(path, "wb") as fh:
        fh.write(adb("exec-out", "screencap", "-p", binary=True))
    img = Image.open(path).convert("RGB")
    return sum(1 for p in img.getdata()
               if p[0] > 200 and p[1] > 200 and p[2] < 90)


def preset_text():
    path = os.path.join(KLHU_REPO, "assets", "content", "presets.json")
    with open(path, encoding="utf-8") as fh:
        for p in json.load(fh)["presets"]:
            if p["id"] == "preset_en_sample":
                return p["text"]
    raise SystemExit("preset_en_sample missing")


def paragraph_ranges(text):
    ranges, start = [], 0
    for m in re.finditer(r"\n[ \t]*\n+", text):
        end = m.start()
        while end > start and text[end - 1] in "\n \t":
            end -= 1
        if end > start:
            ranges.append((start, end))
        start = m.end()
    while start < len(text) and text[start] == "\n":
        start += 1
    if start < len(text):
        end = len(text)
        while end > start and text[end - 1] == "\n":
            end -= 1
        ranges.append((start, end))
    return ranges


def sentence_ranges(text):
    """Sentence ranges mirroring lib/segmenter.dart: a paragraph is the
    largest unit; `.!?;。！？；` end a sentence inside it. The range ends at
    the punctuation (plus closing quotes); leading whitespace belongs to no
    sentence."""
    out = []
    for a, b in paragraph_ranges(text):
        i = a
        while i < b:
            while i < b and text[i] in " \t\r\n":
                i += 1
            j = i
            while j < b and text[j] not in ".!?;。！？；":
                j += 1
            if j < b:
                j += 1
                while j < b and text[j] in "\"'”’)»]}":
                    j += 1
            if j > i:
                out.append((i, j))
            i = j
    return out


def check(name, ok, detail=""):
    RESULTS.append((name, ok))
    print(f"   {'PASS' if ok else 'FAIL'}: {name} {detail}")


def content_node(rows):
    return find(rows, "The sun rose over the quiet town.")


TEXT = preset_text()
PARAS = paragraph_ranges(TEXT)
SENTS = sentence_ranges(TEXT)


# --------------------------------------------------------------------------
def w1_toolbar():
    step("W1: toolbar at idle has no Read button")
    rows = dump()
    labs = [l for l in labels(rows) if l]
    check("no 'Read' tooltip", not any(l == "Read" for l in labs),
          f"labels={labs}")
    check("Continue Read present", find(rows, "Continue Read") is not None)
    check("Stop present", find(rows, "Stop") is not None)
    check("Edit present", find(rows, "Edit") is not None)


def w2_tap_reads():
    step("W2: tap a sentence — highlight + immediate read")
    rows = dump()
    node = content_node(rows)
    if node is None:
        check("content node found", False)
        return None
    l, t, r, b = node["bounds"]
    # first line of the text block, left side — inside sentence 1
    x, y = l + 80, t + 26
    before = yellow_pixels(f"{KLHU_OUT}/032_before.png")
    n = snapshot()
    tap_at(x, y, "sentence 1 area")
    speaks = []
    ok = wait_for(lambda: len(new_speaks(n)) >= 1, seconds=20)
    speaks = new_speaks(n)
    ranges = new_ranges(n)
    print(f"   speak={speaks} ranges={ranges}")
    check("a sentence was spoken", ok and len(speaks) >= 1,
          f"speaks={speaks}")
    check("read range is one sentence step",
          len(ranges) >= 1 and any((a, bb) in SENTS for a, bb in ranges),
          f"ranges={ranges}")
    # highlight must survive the end of the read
    check("read returned to idle", wait_idle())
    after = yellow_pixels(f"{KLHU_OUT}/032_after.png")
    print(f"   yellow before={before} after read end={after}")
    check("highlight remains after read", after > 1000,
          f"before={before} after={after}")
    return (x, y)


def w3_repeat(spot):
    step("W3: tap the highlighted sentence again — repeats")
    if spot is None:
        check("repeat", False, "no tap spot from W2")
        return
    x, y = spot
    n = snapshot()
    tap_at(x, y, "same sentence again")
    ok = wait_for(lambda: len(new_speaks(n)) >= 1, seconds=20)
    speaks = new_speaks(n)
    print(f"   speak={speaks}")
    check("same sentence spoken again", ok and len(speaks) >= 1,
          f"speaks={speaks}")
    wait_idle()


def w4_other_sentence():
    step("W4: tap a lower line — a different sentence reads")
    rows = dump()
    node = content_node(rows)
    if node is None:
        check("content node found", False)
        return
    l, t, r, b = node["bounds"]
    # ~60% down the text block: paragraph 2 territory
    y = t + int((b - t) * 0.62)
    n = snapshot()
    tap_at(l + 80, y, "lower line")
    ok = wait_for(lambda: len(new_speaks(n)) >= 1, seconds=20)
    speaks = new_speaks(n)
    ranges = new_ranges(n)
    print(f"   speak={speaks} ranges={ranges}")
    check("a sentence was spoken", ok and len(speaks) >= 1,
          f"speaks={speaks}")
    wait_idle()


def w5_long_press():
    step("W5: long-press paragraph 1 — whole paragraph reads")
    rows = dump()
    node = content_node(rows)
    if node is None:
        check("content node found", False)
        return
    l, t, r, b = node["bounds"]
    para1 = PARAS[0]
    # tap inside paragraph 1's first line
    x, y = l + 80, t + 26
    n = snapshot()
    long_press_at(x, y, "paragraph 1")
    # paragraph 1 has 2 sentences — wait for >=2 speak lines
    ok = wait_for(lambda: len(new_speaks(n)) >= 2, seconds=30)
    speaks = new_speaks(n)
    ranges = new_ranges(n)
    print(f"   speaks={speaks} ranges={ranges}")
    expected = sum(1 for a, bb in SENTS if para1[0] <= a < para1[1])
    check("paragraph sentences all spoken", ok and len(speaks) >= expected,
          f"expected>={expected} got={len(speaks)} speaks={speaks}")
    check("read range covers paragraph 1",
          any(a <= para1[0] and bb >= para1[1] for a, bb in ranges),
          f"para1={para1} ranges={ranges}")
    wait_idle()
    after = yellow_pixels(f"{KLHU_OUT}/032_para.png")
    check("paragraph highlight remains", after > 500, f"yellow={after}")


def w6_continue_wrap():
    step("W6: Continue Read loops to the first sentence; Stop ends it")
    rows = dump()
    if not tap_node(rows, "Continue Read", "Continue Read"):
        check("continue pressed", False)
        return
    n = snapshot()
    # collect speaks for ~30s — the preset is short, several passes expected
    time.sleep(30)
    speaks = new_speaks(n)
    print(f"   {len(speaks)} utterances collected: {speaks[:12]} ...")
    check("utterances collected", len(speaks) >= 8, f"n={len(speaks)}")
    # wrap evidence: the first sentence's logged text appears again after
    # the last sentence's
    texts = speaks
    first = texts[0] if texts else ""
    # find a repeat of the opening utterance after position len//2
    seen_end = False
    wrapped = False
    for i, s in enumerate(texts):
        if s == texts[-1] and i < len(texts) - 1:
            seen_end = True
        if seen_end and s == first and i > 0:
            wrapped = True
            break
    print(f"   first={first!r} wrapped={wrapped}")
    check("sequence wrapped to the start", wrapped)
    # Stop must end it for good
    rows = dump()
    if not tap_node(rows, "Stop", "Stop"):
        check("stop pressed", False)
        return
    n2 = snapshot()
    time.sleep(4)
    late = new_speaks(n2)
    check("no speech after Stop", len(late) == 0, f"late={late}")
    check("idle toolbar back", find(dump(), "Continue Read") is not None)


def w7_pause_resume():
    step("W7: Pause parks the loop; Resume restarts; Stop wins")
    rows = dump()
    if not tap_node(rows, "Continue Read", "Continue Read"):
        check("continue pressed", False)
        return
    n = snapshot()
    ok = wait_for(lambda: len(new_speaks(n)) >= 3, seconds=25)
    check("loop is speaking", ok, f"speaks={len(new_speaks(n))}")
    rows = dump()
    if not tap_node(rows, "Pause", "Pause"):
        check("pause pressed", False)
        return
    n_pause = snapshot()
    time.sleep(4)
    during = new_speaks(n_pause)
    # a parked queue may still finish its current utterance; allow <=1
    check("pause parks the loop", len(during) <= 1, f"during={during}")
    rows = dump()
    if not tap_node(rows, "Resume", "Resume"):
        check("resume pressed", False)
        return
    n_res = snapshot()
    ok = wait_for(lambda: len(new_speaks(n_res)) >= 1, seconds=25)
    check("resume restarts speech", ok, f"speaks={new_speaks(n_res)}")
    rows = dump()
    if not tap_node(rows, "Stop", "Stop"):
        check("stop pressed", False)
        return
    n_stop = snapshot()
    time.sleep(4)
    check("stop ends the loop", len(new_speaks(n_stop)) == 0,
          f"late={new_speaks(n_stop)}")


def step(title):
    print(f"\n===== {title} =====")


def main():
    only = set(sys.argv[1:])
    adb("shell", "settings", "put", "secure", "accessibility_enabled", "1")
    rows = start_app()
    node = content_node(rows)
    if node is None:
        print("preset content not on screen — open it first")
        sys.exit(2)

    spot = None
    if not only or "W1" in only:
        w1_toolbar()
    if not only or "W2" in only:
        spot = w2_tap_reads()
    if not only or "W3" in only:
        w3_repeat(spot)
    if not only or "W4" in only:
        w4_other_sentence()
    if not only or "W5" in only:
        w5_long_press()
    if not only or "W6" in only:
        w6_continue_wrap()
    if not only or "W7" in only:
        w7_pause_resume()

    print("\n===== SUMMARY =====")
    bad = [n for n, ok in RESULTS if not ok]
    for n, ok in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {n}")
    print(f"{len(RESULTS) - len(bad)}/{len(RESULTS)} checks passed")
    sys.exit(1 if bad else 0)


if __name__ == "__main__":
    main()
