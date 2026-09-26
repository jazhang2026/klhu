#!/usr/bin/env python3
"""klhu device walk — 012 quickstart rows 31 and 34.

Row 31: a real render produces a real video (landscape, then vertical), asserted
with the host's `ffprobe`.
Row 34: a confirmed Stop at about half way leaves no file, an empty cache, and
the earlier video untouched.

The app's own evidence lines are the clock here — nothing waits on a fixed
sleep for a moment that lasts seconds:
    klhu render done: <path> <ms>ms <bytes>B frames=<n>
and the page's own dump shows `Rendering video, sentence i of n` while it runs.

Usage:  python3 klhu_walk_video.py 31
        python3 klhu_walk_video.py 34
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.
"""
import hashlib
import json
import os
import re
import shutil
import subprocess
import sys
import time

DEV = "emulator-5554"
PKG = "com.example.klhu"
XML = "/sdcard/klhu_walk.xml"
LOCAL = "/tmp/klhu_walk.xml"
OUT = os.environ.get("KLHU_OUT", "/tmp/klhu_out")
CACHE = f"/data/data/{PKG}/cache"

# SC-006's placeholder was <=5 minutes for a one-minute reading; this pre-set is
# far shorter, so the walk's own ceiling is generous but finite.
RENDER_TIMEOUT = 300

RESULTS = []


def adb(*args, **kw):
    return subprocess.run(["adb", "-s", DEV, *args], capture_output=True,
                          text=True, **kw)


def dump(retries=3):
    """A fresh dump, into a file deleted first: a failed pull can never be read
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


def show(rows, limit=14):
    for r in rows[:limit]:
        print(f"   [{r['x']:>4},{r['y']:>4}]"
              f"{'' if r['enabled'] else ' (disabled)'} "
              f"{(r['desc'] or r['text'])!r}")


def find(rows, needle, below=None, above=None, exact=False):
    """Rows whose label contains `needle`, optionally in a band of the screen
    (the app bar's Stop and the confirmation's Stop carry the same word) — and
    optionally exactly, because a dialog's title also contains its action's
    word ('Stop making the video?' is not the button)."""
    hits = []
    for r in rows:
        name = r["desc"] or r["text"]
        if (name == needle) if exact else (needle in name):
            if below is not None and r["y"] < below:
                continue
            if above is not None and r["y"] > above:
                continue
            hits.append(r)
    return hits


def tap(rows, needle, label=None, below=None, above=None, exact=False):
    hits = find(rows, needle, below=below, above=above, exact=exact)
    if not hits:
        print(f"   NOT FOUND: {needle!r} (exact={exact}, below={below}, "
              f"above={above}) — visible: {labels(rows)[:12]}")
        return False
    r = hits[0]
    adb("shell", "input", "tap", str(r["x"]), str(r["y"]))
    print(f"   tap {label or needle!r} @{r['x']},{r['y']}")
    return True


def on_screen(rows, needle):
    return any(needle in (r["desc"] or r["text"]) for r in rows)


def step(title):
    print(f"\n===== {title} =====")


def check(name, ok, detail=""):
    RESULTS.append((name, bool(ok), detail))
    print(f"   {'PASS' if ok else 'FAIL'} {name}"
          f"{(' — ' + detail) if detail else ''}")


def logcat():
    return adb("logcat", "-d", "-v", "time").stdout


def clear_logcat():
    adb("logcat", "-c")


def start_app():
    adb("shell", "am", "start", "-n", f"{PKG}/.MainActivity")
    time.sleep(6)


def hard_restart():
    """Fresh state: the shipped pre-set, no aspect memory, an empty cache."""
    adb("shell", "pm", "clear", PKG)
    time.sleep(1)
    start_app()


def shell_ls(path):
    return adb("shell", "run-as", PKG, "ls", "-la", path).stdout


def shell_files(path):
    """Every file under `path`, recursively — the cache must hold nothing of the
    render's, wherever it put it."""
    return adb("shell", "run-as", PKG, "find", path, "-type", "f").stdout


def sha256_of(data):
    return hashlib.sha256(data).hexdigest()


LIBRARY = f"/data/user/0/{PKG}/app_flutter"


def cat(path):
    return subprocess.run(
        ["adb", "-s", DEV, "exec-out", "run-as", PKG, "cat", path],
        capture_output=True).stdout


def library_state():
    """The app's own library: every file and its hash. A cancel must add and
    rewrite nothing here — in US1 nothing is kept yet, so this is what stands in
    for row 34's 'the kept video is still in the gallery' (US3's T030 owns the
    kept file itself)."""
    state = {}
    for path in [l.strip() for l in shell_files(LIBRARY).splitlines() if l.strip()]:
        state[path] = sha256_of(cat(path))
    return state


def pull(path, dest):
    """Pulls the app's own private file out of the debug build.

    Answers (data, ok): a deleted file makes `run-as cat` fail, and its error
    text must never be read as the file's own bytes."""
    out = subprocess.run(
        ["adb", "-s", DEV, "exec-out", "run-as", PKG, "cat", path],
        capture_output=True)
    ok = out.returncode == 0 and not out.stdout.startswith(b"cat: ")
    data = out.stdout if ok else b""
    os.makedirs(os.path.dirname(dest), exist_ok=True)
    with open(dest, "wb") as fh:
        fh.write(data)
    return data, ok


def probe(path):
    """One call, every field the checks below assert on — an `-show_entries`
    that omits a field reads as None, which looks like a broken video."""
    cmd = ["ffprobe", "-v", "error", "-print_format", "json", "-count_frames",
           "-show_entries",
           "stream=codec_type,codec_name,width,height,r_frame_rate,"
           "avg_frame_rate,nb_read_frames,channels,sample_rate:"
           "format=duration,format_name,size",
           path]
    out = subprocess.run(cmd, capture_output=True, text=True)
    if out.returncode != 0:
        print("   ffprobe failed:", out.stderr.strip()[:200])
        return None
    return json.loads(out.stdout)


def duration_s(probed):
    try:
        return float(probed["format"]["duration"])
    except (KeyError, TypeError, ValueError):
        return None


RENDER_RUN_RE = (r"klhu render slot=(\d+)/(\d+) frame=(\d+)/(\d+) kind=(\w+) "
                 r"frames=(\d+) band=(\S+) range=(\S+) span=(\S+) text=(\d+)")
RENDER_PREVIEW_RE = r"klhu render preview frame=(\d+) kind=(\w+)"


# --------------------------------------------------------------------------
def render(where, aspect_label, pair=None):
    """Opens the aspect prompt, picks `aspect_label`, and waits for the render to
    report. Answers (path, ms, bytes, frames, wall_seconds) or None.

    With [pair] (a list), also samples — while the painting pass runs — what the
    page had on screen against what the renderer had written, appending
    `(renderer line, page line, page's labels)` per sample. Both sides print
    their own frame, so the sample is two independent readings of one moment.
    """
    clear_logcat()
    rows = dump()
    if not tap(rows, "Video", label="the video action"):
        return None
    time.sleep(1.5)
    rows = dump()
    show(rows, 10)
    if not on_screen(rows, "Video format"):
        check(f"{where}: the aspect prompt opened", False,
              f"visible: {labels(rows)[:8]}")
        return None
    check(f"{where}: the aspect prompt opened", True)
    if aspect_label and not tap(rows, aspect_label, label=aspect_label):
        return None
    time.sleep(0.5)
    rows = dump()
    if not tap(rows, "Start", label="Start"):
        return None
    started = time.time()

    # The page's own progress is the evidence that the render is running, and
    # the app's done line is what it finished with.
    seen_progress = False
    done = None
    while time.time() - started < RENDER_TIMEOUT:
        log = logcat()
        m = re.search(r"klhu render done: (\S+) (\d+)ms (\d+)B frames=(\d+)", log)
        if m:
            done = (m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)))
            break
        if not seen_progress:
            rows = dump()
            if on_screen(rows, "Rendering video"):
                seen_progress = True
                print(f"   progress: {[l for l in labels(rows) if 'Rendering' in l]}")
        if pair is not None and re.search(RENDER_RUN_RE, log):
            written = re.findall(RENDER_RUN_RE, log)
            shown = re.findall(RENDER_PREVIEW_RE, log)
            if shown:
                rows = dump()
                on = tuple(l for l in labels(rows) if "Rendering" in l)
                pair.append((written, shown[-1], on))
                print(f"   pairing: renderer up to {written[-1][:4]} "
                      f"page {shown[-1]} screen {list(on)}")
        time.sleep(2)
    wall = time.time() - started
    if not done:
        check(f"{where}: the render reported done", False,
              f"no 'klhu render done' within {RENDER_TIMEOUT}s")
        print("   logcat tail:")
        for line in logcat().splitlines()[-25:]:
            print("     ", line.strip())
        return None
    check(f"{where}: the render reported done", True, f"{wall:.0f}s wall")
    check(f"{where}: the page showed progress while it ran", seen_progress)
    path, ms, size, frames = done
    print(f"   done: path={path} {ms}ms {size}B frames={frames}")

    # SC-001: the reader is told the file's name and its length.
    snack = None
    for _ in range(6):
        rows = dump()
        hits = [l for l in labels(rows) if l.startswith("Video made")]
        if hits:
            snack = hits[0]
            break
        time.sleep(1)
    check(f"{where}: the page reported the file's name and length",
          snack is not None, repr(snack))
    if snack:
        m = re.search(r"\((\d+) s\)", snack)
        check(f"{where}: the reported length is the render's own",
              m is not None and abs(int(m.group(1)) - round(ms / 1000)) <= 1,
              f"page said {m.group(1) if m else '?'} s, render said {ms} ms")
    return path, ms, size, frames, wall


def ffprobe_checks(where, file, ms, frames, expect_w, expect_h):
    probed = probe(file)
    if not probed:
        check(f"{where}: ffprobe read the file", False)
        return False
    streams = probed.get("streams", [])
    video = [s for s in streams if s.get("codec_type") == "video"]
    audio = [s for s in streams if s.get("codec_type") == "audio"]
    check(f"{where}: exactly one video stream", len(video) == 1,
          str([s.get("codec_name") for s in video]))
    check(f"{where}: exactly one audio stream", len(audio) == 1,
          str([s.get("codec_name") for s in audio]))
    if video:
        v = video[0]
        check(f"{where}: the video is H.264", v.get("codec_name") == "h264",
              str(v.get("codec_name")))
        check(f"{where}: the frames are exactly {expect_w}x{expect_h}",
              (v.get("width"), v.get("height")) == (expect_w, expect_h),
              f"{v.get('width')}x{v.get('height')}")
        rate, avg = v.get("r_frame_rate"), v.get("avg_frame_rate")
        check(f"{where}: the frame rate is constant", rate == avg and rate,
              f"r={rate} avg={avg}")
        read = v.get("nb_read_frames")
        if read:
            check(f"{where}: the file holds the frames the plan asked for",
                  int(read) == frames, f"file {read} vs render {frames}")
            span = duration_s(probed)
            if span:
                # Constant rate: the frames divided by the span must be the rate.
                num, den = (rate or "0/1").split("/")
                fps = float(num) / float(den or 1)
                check(f"{where}: frames / duration is that rate",
                      abs(int(read) / span - fps) <= 0.5,
                      f"{int(read) / span:.2f} vs {fps:.2f}")
    if audio:
        a = audio[0]
        check(f"{where}: the audio is AAC", a.get("codec_name") == "aac",
              str(a.get("codec_name")))
    span = duration_s(probed)
    # SC-002: the duration is the sum of the sentences' audio plus the title
    # card and the hold — which is exactly what the render itself reports.
    check(f"{where}: the duration is the render's own, within 2 s",
          span is not None and abs(span * 1000 - ms) <= 2000,
          f"ffprobe {span:.2f}s vs render {ms / 1000:.2f}s")
    print(f"   ffprobe: {json.dumps({k: probed['format'].get(k) for k in ('format_name', 'duration', 'size')})}")
    return True


# --------------------------------------------------------------------------
# What a frame holds (row 32): the app's background to the edges, the reader's
# text inside the column, and — on a sentence's frame — the app's own yellow
# band. Measured from the file's pixels, never from the app's own say-so.
BG_SAMPLE_TOL = 12          # a background pixel, allowing the encoder's own noise
BAND_COLOUR = (255, 235, 59)  # Colors.yellow, the app's highlight (FR-014)
BAND_TOL = 12

REPO = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", ".."))


def preset_sentences():
    """The shipped pre-set's sentences, from the app's own asset, to name the
    sentence a slot index stands for. (Its English entry, the walk's content.)"""
    with open(os.path.join(REPO, "assets", "content", "presets.json")) as f:
        presets = json.load(f)["presets"]
    entry = next(p for p in presets if p["language"] == "en")
    return [s.strip() for s in re.findall(r"[^.!?\n]+[.!?]", entry["text"])]


def frame_rgb(file, number, w, h):
    """One frame's pixels by frame number — exact, not by seeking a second."""
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", file,
         "-vf", f"select=eq(n\\,{number})", "-frames:v", "1",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True)
    data = out.stdout
    return data if len(data) == w * h * 3 else None


def coarse_frames(file):
    """Every frame at 96x54, in order: enough to see a band and a margin, cheap
    enough to look at all of them."""
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", file,
         "-vf", "scale=96:54:flags=area", "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True)
    step = CW * CH * 3
    return [out.stdout[i:i + step] for i in range(0, len(out.stdout) - step + 1, step)]


CW, CH = 96, 54


def at(rgb, w, x, y):
    i = (y * w + x) * 3
    return (rgb[i], rgb[i + 1], rgb[i + 2])


def is_bg(px, bg, tol=BG_SAMPLE_TOL):
    return all(abs(a - b) <= tol for a, b in zip(px, bg))


def is_band(px):
    """Yellow-ish, hue-based: a scaled frame blends the band with the paper, so
    the test is the colour's direction rather than its exact code."""
    r, g, b = px
    return r > 140 and g > 120 and b < 130 and r - b > 60


def scan_frame(rgb, w, h, bg, column, guard=1, stride=1):
    """(band pixels, non-background pixels outside the column, the band's box,
    the ink's box), with the column given as `(left, top, width)` in *this*
    grid's own pixels. The caller works it out from the file's size and scales
    it, because a thumbnail is not the frame's own aspect — deriving the column
    from the thumbnail's dimensions would put the margins in the wrong place.

    [stride] skips pixels: at the file's own size that is what makes a 36-frame
    pass take a minute rather than ten, and the claims it feeds — a band is
    there or it is not, nothing is outside the column — survive it.
    """
    left, top, col_w = column
    band = ink = outside = 0
    band_box = ink_box = None
    for y in range(0, h, stride):
        for x in range(0, w, stride):
            px = at(rgb, w, x, y)
            inside = (left - guard <= x <= left + col_w + guard
                      and top - guard <= y <= h - top + guard)
            if is_band(px):
                band += 1
                if not inside:
                    outside += 1
                band_box = _grow(band_box, (x, y, x, y))
            elif not is_bg(px, bg):
                ink += 1
                if inside:
                    ink_box = _grow(ink_box, (x, y, x, y))
                else:
                    outside += 1
    return band, outside, band_box, ink_box


def _grow(box, add):
    if box is None:
        return add
    return (min(box[0], add[0]), min(box[1], add[1]),
            max(box[2], add[2]), max(box[3], add[3]))


def column_of(w, h):
    col_w = min(0.88 * w, h)
    return (w - col_w) / 2.0, 0.10 * h, col_w


def scaled_column(w, h, tw, th):
    """The frame's own column, in a `tw`x`th` grid's pixels: x and y scale
    separately, because a thumbnail of a 9:16 frame is not 9:16."""
    left, top, col_w = column_of(w, h)
    return left * tw / w, top * th / h, col_w * tw / w


# --------------------------------------------------------------------------
def row_31():
    step("31 setup: fresh install state, the shipped pre-set")
    hard_restart()
    rows = dump()
    show(rows, 8)
    check("31: the page is idle with content and the video action",
          on_screen(rows, "Video") and not on_screen(rows, "Rendering video"))

    for aspect, name, w, h in (
        ("16:9 landscape 1080p", "landscape", 1920, 1080),
        ("9:16 vertical (Shorts)", "vertical", 1080, 1920),
    ):
        step(f"31: a real render, {aspect}")
        result = render(f"31/{name}", aspect)
        if not result:
            check(f"31/{name}: the render produced a file", False)
            continue
        path, ms, size, frames, wall = result
        dest = os.path.join(OUT, f"{name}.mp4")
        data, pulled = pull(path, dest)
        check(f"31/{name}: the file came off the device and is not empty",
              pulled and len(data) > 10000 and len(data) == size,
              f"{len(data)}B on the host, app said {size}B")
        print(f"   artifact: {dest} sha256={sha256_of(data)[:16]}…")
        ffprobe_checks(f"31/{name}", dest, ms, frames, w, h)


def row_34():
    step("34 setup: fresh install state")
    hard_restart()

    # The spec's first step is "keep a video for a content" — keeping is US3's
    # file store, so what stands in for it here is the render's own working
    # copy, pulled out so its bytes can be compared afterwards, plus a snapshot
    # of the app's library, which the cancel must leave alone.
    step("34: an earlier video exists (the working copy, as US1 leaves it)")
    library_before = library_state()
    print(f"   library before: {len(library_before)} file(s)")
    result = render("34/first", "16:9 landscape 1080p")
    check("34: the earlier render produced a file", result is not None)
    if not result:
        return
    path, ms, size, frames, wall = result
    earlier, pulled = pull(path, os.path.join(OUT, "34_earlier.mp4"))
    earlier_sha = sha256_of(earlier)
    check("34: the earlier file came off the device", pulled, f"{len(earlier)}B")
    print(f"   earlier: {path} {size}B sha256={earlier_sha[:16]}…")
    print("   NOTE: 'still in the gallery, still playable' is US3's keep (T030);"
          " with nothing kept yet the earlier file is the cache's working copy,")
    print("   which row 34 itself requires the cache to be free of afterwards.")

    step("34: render again, and stop it about half way")
    clear_logcat()
    rows = dump()
    if not tap(rows, "Video", label="the video action"):
        return
    time.sleep(1.5)
    rows = dump()
    if not on_screen(rows, "Video format"):
        check("34: the aspect prompt opened", False, f"visible: {labels(rows)[:8]}")
        return
    # The remembered choice (A8) is already landscape; Start confirms it.
    tap(rows, "Start", label="Start")
    half = wall / 2.0
    time.sleep(half)

    rows = dump()
    progress = [l for l in labels(rows) if "Rendering video" in l]
    check("34: the render was under way when Stop was tapped",
          bool(progress), repr(progress))
    # The page's toolbar is at the bottom of the screen and a dialog's buttons
    # sit in the middle: the two Stops are told apart by where they are.
    if not tap(rows, "Stop", label="Stop (the toolbar's)", below=1800,
               exact=True):
        return
    time.sleep(1.5)
    rows = dump()
    check("34: stopping asks first", on_screen(rows, "Stop making the video?"),
          repr([l for l in labels(rows) if "Stop" in l][:4]))
    if not tap(rows, "Stop", label="Stop (the confirmation's)", above=1800,
               exact=True):
        return
    time.sleep(3)
    rows = dump()
    check("34: the page is idle again", on_screen(rows, "Video")
          and not on_screen(rows, "Rendering video"))
    check("34: the render's chrome is gone from the page",
          not on_screen(rows, "Video preview")
          and not on_screen(rows, "Stop making the video?"),
          repr(labels(rows)[:8]))
    # No message is asserted here: on a Stop the page simply goes idle, and
    # `videoNotSavedMessage` belongs to US3's review (T029).

    step("34: nothing was left behind, and the earlier file is untouched")
    files = [l.strip() for l in shell_files(CACHE).splitlines() if l.strip()]
    print("   cache files now:", files or "(none)")
    check("34: the cache holds no working copy",
          not any(f.endswith(".mp4") for f in files),
          repr([f for f in files if f.endswith(".mp4")]))
    check("34: the cache holds no per-sentence audio and no render directory",
          not any(f.endswith(".wav") or "render_" in f for f in files),
          repr([f for f in files if f.endswith(".wav") or "render_" in f]))
    still, still_ok = pull(path, os.path.join(OUT, "34_after_cancel.mp4"))
    check("34: the earlier render's working copy is gone from the cache",
          not still_ok, f"{len(still)}B read back; ok={still_ok}")
    library_after = library_state()
    check("34: the app's library was neither added to nor rewritten",
          library_after == library_before,
          f"{len(library_before)} -> {len(library_after)} files; "
          f"changed: {[k for k in library_after if library_before.get(k) != library_after[k]]}")
    # The file itself, as it was when it was made: evidence it was a real video
    # and still parses. Playing it *on the device* is US3's (T030).
    ok = ffprobe_checks("34/earlier", os.path.join(OUT, "34_earlier.mp4"),
                        ms, frames, 1920, 1080)
    check("34: the earlier video's own streams still parse", ok)


def has_colour(rgb, w, h, colour, tol=BAND_TOL, stride=2):
    """Whether any sampled pixel is [colour], within the encoder's own slack."""
    for y in range(0, h, stride):
        for x in range(0, w, stride):
            if all(abs(a - b) <= tol
                   for a, b in zip(at(rgb, w, x, y), colour)):
                return True
    return False


# --------------------------------------------------------------------------
def row_32():
    step("32 setup: fresh install state, the shipped pre-set")
    hard_restart()
    sentences = preset_sentences()
    print(f"   the pre-set's {len(sentences)} sentences, e.g. {sentences[0]}")

    for aspect, name, w, h in (
        ("16:9 landscape 1080p", "landscape", 1920, 1080),
        ("9:16 vertical (Shorts)", "vertical", 1080, 1920),
    ):
        step(f"32: a real render at {aspect}, watching the page as it paints")
        pairs = []
        result = render(f"32/{name}", aspect, pair=pairs)
        if not result:
            check(f"32/{name}: the render produced a file", False)
            continue
        path, ms, size, frames, wall = result
        dest = os.path.join(OUT, f"32_{name}.mp4")
        data, pulled = pull(path, dest)
        check(f"32/{name}: the file came off the device and is not empty",
              pulled and len(data) > 10000, f"{len(data)}B")

        log = logcat()
        runs = [dict(slot=int(a), start=int(c), kind=e, count=int(f2), band=g)
                for a, b, c, d, e, f2, g, h, i, j in re.findall(RENDER_RUN_RE, log)]
        check(f"32/{name}: the renderer reported the pictures it wrote",
              bool(runs) and all(r["total"] == frames
                                 for r in [dict(total=int(d)) for _, _, _, d, _, _, _, _, _, _ in
                                           re.findall(RENDER_RUN_RE, log)]),
              f"{len(runs)} runs, file has {frames} frames")
        if not runs:
            continue
        # The renderer's own account of the band: the card has none, every
        # sentence's frame has one, inside the column. The pixel checks further
        # down are the other half of this — a file that ignores the picture the
        # app drew (which is what a picture cached across calls produces) passes
        # one and fails the other.
        left, top, col_w = column_of(w, h)
        words = [r["band"] for r in runs if r["kind"] != "title"]
        widths = [int(word.split("x")[0]) for word in words if word != "none"]
        # The rect can overhang the column by a line's trailing space — a
        # selection's boxes include it — and the column's own clip is what keeps
        # the *painted* band inside, which the pixel checks below prove.
        overhang = col_w * 0.02
        check(f"32/{name}: the renderer's own band, on every sentence's frame",
              runs[0]["band"] == "none"
              and all(word != "none" for word in words)
              and all(0 < width <= col_w + overhang for width in widths),
              f"card {runs[0]['band']}, sentences {words}")
        # The runs are the file's own timeline: from 0, end to end, and up to
        # exactly the frames the file holds.
        tiled = runs[0]["start"] == 0
        for a, b in zip(runs, runs[1:]):
            tiled = tiled and a["start"] + a["count"] == b["start"]
        ends = runs[-1]["start"] + runs[-1]["count"]
        check(f"32/{name}: the runs tile the file frame for frame",
              tiled and ends == frames,
              f"last run ends at {ends}, file has {frames}")
        check(f"32/{name}: the first picture is the card, the rest are sentences",
              runs[0]["kind"] == "title"
              and all(r["kind"] == "sentence" for r in runs[1:]),
              str([r["kind"] for r in runs]))

        # FR-020 on the device: the picture on the page is one the renderer
        # wrote, for the same slot, and the page's own reading moves forward.
        starts = {r["start"]: r for r in runs}
        order = [r["start"] for r in runs]
        good, shown_slots = [], []
        for written, shown, on in pairs:
            page_frame, page_kind = int(shown[0]), shown[1]
            newest = int(written[-1][2])
            run = starts.get(page_frame)
            behind = (order.index(newest) - order.index(page_frame)
                      if newest in starts and page_frame in starts else 99)
            if run and run["kind"] == page_kind and 0 <= behind <= 1:
                good.append(page_frame)
                shown_slots.append(run["slot"])
        check(f"32/{name}: the page showed a picture the renderer had written",
              bool(pairs) and len(good) == len(pairs),
              f"{len(good)}/{len(pairs)} pairings")
        check(f"32/{name}: what the page showed moved forward with the render",
              shown_slots == sorted(shown_slots), str(shown_slots))
        for frame in good:
            run = starts[frame]
            what = ("the title card" if run["kind"] == "title"
                    else sentences[run["slot"] - 1]
                    if 1 <= run["slot"] <= len(sentences) else f"slot {run['slot']}")
            print(f"   the page at frame {frame} was {what!r}")

        # Every frame of the file, at a grid big enough for a band and a margin:
        # the app's look, no chrome, and a band exactly on the sentences' frames.
        step(f"32/{name}: every frame of the file, at {CW}x{CH}")
        thumbs = coarse_frames(dest)
        check(f"32/{name}: every frame was read back", len(thumbs) == frames,
              f"{len(thumbs)} frames read, render said {frames}")
        bg = at(thumbs[0], CW, 2, 2)
        grid = scaled_column(w, h, CW, CH)
        banded = clean = 0
        bad = []
        for i, thumb in enumerate(thumbs):
            band, outside, _, _ = scan_frame(thumb, CW, CH, bg, grid)
            run = next((r for r in runs
                        if r["start"] <= i < r["start"] + r["count"]), None)
            want = run is not None and run["kind"] != "title"
            if (band > 0) == want and outside == 0:
                clean += 1
            else:
                bad.append((i, band, outside, run["kind"] if run else None))
            banded += 1 if band > 0 else 0
        check(f"32/{name}: every frame is the app's own look, and no chrome",
              clean == len(thumbs),
              f"{clean}/{len(thumbs)} frames; first bad: {bad[:3]}")
        print(f"   checked {clean}/{frames} frames "
              f"({100.0 * clean / max(1, frames):.0f}%) at {CW}x{CH}: "
              f"{banded} carry the band, {len(thumbs) - banded} do not")

        # And three frames of every slot at the file's own size, where the
        # colours and the column's own edges can be read.
        step(f"32/{name}: three frames of every slot at {w}x{h}")
        print(f"   the column, by the painter's rule: {col_w:.0f}px wide from "
              f"x={left:.0f} to {w - left:.0f}, y={top:.0f} to {h - top:.0f}")
        sampled, details = 0, []
        for run in runs:
            first = run["start"]
            last = run["start"] + run["count"] - 1
            for f in sorted({first, (first + last) // 2, last}):
                rgb = frame_rgb(dest, f, w, h)
                sampled += 1
                if rgb is None:
                    details.append((f, ["no such frame"]))
                    continue
                band, outside, band_box, ink_box = scan_frame(
                    rgb, w, h, bg, (left, top, col_w), stride=2)
                want = run["kind"] != "title"
                issues = []
                if not is_bg(at(rgb, w, 2, 2), bg):
                    issues.append(f"corner is {at(rgb, w, 2, 2)}")
                if (band > 0) != want:
                    issues.append(f"band is {band}px, wanted {'a band' if want else 'none'}")
                if outside:
                    issues.append(f"{outside} px outside the column")
                if ink_box is None:
                    issues.append("no text inside the column")
                if want and not has_colour(rgb, w, h, BAND_COLOUR):
                    issues.append(f"no pixel is the app's own yellow {BAND_COLOUR}")
                if band_box:
                    ink = (f"ink x={ink_box[0]}..{ink_box[2]}"
                           if ink_box else "no ink")
                    print(f"   frame {f:>4} {run['kind']:>8}: band x={band_box[0]}"
                          f"..{band_box[2]} y={band_box[1]}..{band_box[3]}, {ink}")
                if issues:
                    details.append((f, issues))
        check(f"32/{name}: every sampled frame holds the app's own look",
              sampled >= 3 * len(runs) and not details,
              f"{sampled - len(details)}/{sampled} frames clean"
              + (f"; first bad: {details[:3]}" if details else ""))


# --------------------------------------------------------------------------
def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("31", "32", "34"):
        print(__doc__)
        sys.exit(2)
    row = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 012 row {row} — device {DEV}, package {PKG}, out {OUT}")
    if not shutil.which("ffprobe") or not shutil.which("ffmpeg"):
        print("ffprobe and ffmpeg are required for this row")
        sys.exit(2)
    {"31": row_31, "32": row_32, "34": row_34}[row]()

    print("\n===== result =====")
    failed = [r for r in RESULTS if not r[1]]
    for name, ok, detail in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}"
              f"{(' — ' + detail) if detail else ''}")
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
