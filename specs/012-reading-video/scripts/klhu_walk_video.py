#!/usr/bin/env python3
"""klhu device walk — 012 quickstart rows 31, 32, 33 and 34.

Row 31: a real render produces a real video (landscape, then vertical), asserted
with the host's `ffprobe`.
Row 32: the amended picture on the device — a frame per slot boundary, each one
its slot's sentence alone, and the on-screen picture is the frame written.
Row 33: the file's whole life — the review played before keeping, one thrown
away, one kept into the gallery under the content's name, played back, shared
through the phone's own list, then deleted behind its warning.
Row 34: a confirmed Stop at about half way leaves no file, an empty cache, and
the earlier video untouched.

The app's own evidence lines are the clock here — nothing waits on a fixed
sleep for a moment that lasts seconds:
    klhu render done: <path> <ms>ms <bytes>B frames=<n>
and the page's own dump shows `Rendering video, sentence i of n` while it runs.

Usage:  python3 klhu_walk_video.py 31
        python3 klhu_walk_video.py 33
        python3 klhu_walk_video.py 34
        KLHU_DEV=37e102a0 python3 klhu_walk_video.py 49   # a physical device
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

DEV = os.environ.get("KLHU_DEV", "emulator-5554")
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
            text = attr("text")
            # A label is a content-desc **or** a text: the app's own widgets come
            # through Flutter's semantics as content-descs, but another app's
            # window — the phone's share sheet, a system dialog — names its
            # buttons in `text`. Keeping only the former makes a chooser that is
            # right there on screen read as an empty screen, which is a probe
            # lying, not a feature missing.
            if not bounds or not (desc or text):
                continue
            n = [int(x) for x in re.findall(r"\d+", bounds)]
            rows.append({
                "desc": desc.replace("&#10;", "\n"),
                "text": text,
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


ALBUM = "/sdcard/Movies/Klhu"


def gallery_videos():
    """What the phone's own video library holds of the app's (FR-011): the files
    in its album, and the MediaStore entries that make them the gallery's.

    `keep` promises both halves — the file in Movies/Klhu and the entry that
    says it is a video — so a check that reads only one of them could pass while
    the reader saw nothing in their gallery."""
    listing = adb("shell", "ls", ALBUM).stdout
    files = sorted(
        l.strip() for l in listing.splitlines()
        if l.strip() and not l.strip().startswith("ls:")
    )
    query = adb(
        "shell", "content", "query",
        "--uri", "content://media/external/video/media",
        "--projection", "_display_name:relative_path",
    )
    entries = []
    album_path = f"Movies/{ALBUM.rsplit('/', 1)[-1]}"
    for line in query.stdout.splitlines():
        if album_path not in line:
            continue
        # `_display_name=<the content's own name>, relative_path=Movies/Klhu/` —
        # and a content's name can hold spaces and commas, so the name ends where
        # the next column starts, not at the first space or comma (`\S+?` read a
        # kept video as "The" and dropped the row: a parse that silently loses
        # rows is worse than one that fails).
        m = re.search(r"_display_name=(.*?), relative_path=", line)
        if m:
            entries.append(m.group(1).strip())
    if not entries and query.stdout.strip():
        print("   media query answered:", query.stdout.strip()[:200])
    if query.stderr.strip():
        print("   media query refused:", query.stderr.strip()[:200])
    return files, sorted(entries)


def clear_album():
    """A fresh install state for the gallery.

    `pm clear` empties the app's own store but not the phone's video library, so
    a row about the library has to clear that itself — otherwise it can pass
    because an earlier run left a file behind, or fail for the same reason."""
    adb("shell", "rm", "-rf", ALBUM)
    listed = adb("shell", "content", "query",
                 "--uri", "content://media/external/video/media",
                 "--projection", "_id:_display_name:relative_path")
    for line in listed.stdout.splitlines():
        if f"Movies/{ALBUM.rsplit('/', 1)[-1]}" not in line:
            continue
        m = re.search(r"_id=(\d+)", line)
        if m:
            adb("shell", "content", "delete", "--uri",
                f"content://media/external/video/media/{m.group(1)}")
    adb("shell", "cmd", "media", "scan", ALBUM)


def players_started():
    """The phone's own audio players that are running.

    A video whose sound is playing is an `AudioTrack` in `started` state, and
    every render carries the reader's voice — so this is what "it plays" looks
    like from outside the app, rather than a claim about a pause button's
    label that the platform never sets (D12)."""
    out = adb("shell", "dumpsys", "audio").stdout
    return [
        l.strip() for l in out.splitlines()
        if re.search(r"state[:=]\s*started", l)
    ]


def raw_nodes():
    """Every node in the dump, with its class and bounds.

    The video's transport controls are the platform's own Android views inside
    the platform view, so they carry no content-desc the app sets — the labelled
    dump cannot see them, which is exactly why the review's playback needs a
    look at the raw tree."""
    subprocess.run(["rm", "-f", LOCAL])
    adb("shell", "uiautomator", "dump", XML)
    adb("pull", XML, LOCAL)
    try:
        xml = open(LOCAL, encoding="utf-8").read()
    except OSError:
        return []
    nodes = []
    for m in re.finditer(r"<node[^>]*>", xml):
        tag = m.group(0)

        def attr(k):
            a = re.search(k + r'="([^"]*)"', tag)
            return a.group(1) if a else ""

        bounds = attr("bounds")
        if not bounds:
            continue
        n = [int(x) for x in re.findall(r"\d+", bounds)]
        nodes.append({
            "cls": attr("class").split(".")[-1],
            "id": attr("resource-id").split("/")[-1],
            "desc": attr("content-desc"),
            "text": attr("text"),
            "x": (n[0] + n[2]) // 2,
            "y": (n[1] + n[3]) // 2,
            "w": n[2] - n[0],
            "h": n[3] - n[1],
        })
    return nodes


def screen_size():
    m = re.search(r"(\d+)x(\d+)", adb("shell", "wm", "size").stdout)
    return (int(m.group(1)), int(m.group(2))) if m else (1080, 2400)


def screen_density():
    """Pixels per dp: what turns the platform's own button sizes into places on
    this screen (the transport controls are the platform's, not the app's)."""
    m = re.search(r"(\d+)", adb("shell", "wm", "density").stdout)
    return (int(m.group(1)) / 160.0) if m else 2.75


def surfaces_of(package=PKG):
    """The surfaces the platform compositor is showing for the app.

    A Flutter platform view is a real Android view inside a surface of its own,
    which is what "the picture is on screen" looks like from outside the app —
    Flutter's own accessibility tree stops at the platform view's edge, so the
    labelled dump cannot show that it is there."""
    out = adb("shell", "dumpsys", "SurfaceFlinger", "--list").stdout
    return [l.strip() for l in out.splitlines() if package in l]


def wait_for(predicate, seconds, every=1.0):
    """Waits for [predicate] to answer something true, and answers it (or None).

    The app's own evidence lines and the phone's own state are the clock here:
    nothing waits a fixed time for something that takes a while."""
    deadline = time.time() + seconds
    while time.time() < deadline:
        answer = predicate()
        if answer:
            return answer
        time.sleep(every)
    return predicate()


def play_in_view(tag, rows):
    """Plays what the page is showing, and answers whether the phone's sound is
    running afterwards.

    The picture is a Flutter platform view, and Flutter's accessibility tree
    stops at its edge: `uiautomator` never shows the platform's own transport
    controls (a run of this row proved that — the raw tree holds the page's three
    buttons and nothing of the player). So the control is reached by where it
    *is*, and what is checked afterwards is the phone's own sound, never the tap.

    Where it is: the page gives the picture the whole area above its own action
    row, and the platform anchors its controller bar to that view's bottom edge
    with the three buttons at the left of the bar — rewind, play, forward. So the
    bar is just above the action row, and play is the middle of the first three
    button widths from the left.
    """
    width, _ = screen_size()
    density = screen_density()
    actions = [r["y"] for r in rows
               if (r["desc"] or r["text"]).strip() in
               ("Discard", "Share", "Save", "Play video")]
    if not actions:
        # The kept video plays on a screen of its own, without the review's three
        # decisions: the page's own action row then sits at the bottom of the
        # screen, which is where the picture's area ends.
        _, height = screen_size()
        print("   no page actions on screen: placing the picture from the screen")
        area_bottom = height - int(105 * density)
    else:
        area_bottom = min(actions) - 60
    centre = area_bottom // 2
    play_x = int(80 * density)
    print(f"   picture area bottom {area_bottom}; controller bar sits at it, "
          f"play button about x={play_x}")

    # Raise the controls (a tap on the picture toggles them), then press play.
    adb("shell", "input", "tap", str(width // 2), str(centre))
    time.sleep(1.2)
    for dy in (30, 60, 100):
        y = area_bottom - int(dy * density / 2.625)
        for x in (play_x, int(150 * density)):
            adb("shell", "input", "tap", str(x), str(y))
            time.sleep(2.5)
            started = players_started()
            if started:
                print(f"   play control answered at ({x}, {y}): {started[0][:80]}")
                return started
            print(f"   ({x}, {y}) started nothing")
    print("   nothing started: the controls were not where the layout says")
    return []


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
    # The message is the review screen's own bottom bar, and it appears with the
    # review rather than with the render — so the wait is on the message itself,
    # and what the page was showing is kept for the failure line.
    snack = None
    seen = []
    for _ in range(12):
        rows = dump()
        hits = [l for l in labels(rows) if l.startswith("Video made")]
        if hits:
            snack = hits[0]
            break
        seen = labels(rows)[:6]
        time.sleep(1)
    check(f"{where}: the page reported the file's name and length",
          bool(snack), snack or f"the page showed: {seen}")
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
    """The app's own text column, in this grid's own pixels — the same rule the
    painter uses (`min(0.92 × width, 1.4 × height)`, from 2026-09-28, when the
    reader asked for longer lines) and the same tenth-of-the-frame margins. It is
    a mirror: when the painter's rule changes, this changes with it."""
    col_w = min(0.92 * w, 1.4 * h)
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

        # A review left up is state the next aspect inherits: the page's own
        # toolbar is behind it, so the next render's tap on 'Video' finds only
        # the review's three decisions and the row reads as "the render failed".
        # Discarding is also what this row wants — a check of one aspect leaves
        # nothing of its own behind.
        rows = dump()
        if tap(rows, "Discard", label="discard the review"):
            time.sleep(1.5)


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
    # Taking the review down is what discards that working copy, so the baseline
    # the cancel is judged against is taken here, after it, not before.
    if tap(dump(), "Discard", label="discard the earlier review"):
        time.sleep(1.5)
    baseline = [l.strip() for l in shell_files(CACHE).splitlines() if l.strip()]
    print("   cache before the second render:", baseline or "(none)")

    step("34: render again, and stop it about half way")
    clear_logcat()
    rows = dump()
    if not tap(rows, "Video", label="the video action"):
        check("34: the video action is there for the second render", False,
              f"visible: {labels(rows)[:8]}")
        return
    time.sleep(1.5)
    rows = dump()
    if not on_screen(rows, "Video format"):
        check("34: the aspect prompt opened", False, f"visible: {labels(rows)[:8]}")
        return
    # The remembered choice (A8) is already landscape; Start confirms it.
    if not tap(rows, "Start", label="Start"):
        check("34: the aspect prompt offers Start", False,
              f"visible: {labels(rows)[:8]}")
        return
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
        check("34: the toolbar's Stop is reachable while it renders", False,
              f"visible: {labels(rows)[:10]}")
        return
    time.sleep(1.5)
    rows = dump()
    check("34: stopping asks first", on_screen(rows, "Stop making the video?"),
          repr([l for l in labels(rows) if "Stop" in l][:4]))
    if not tap(rows, "Stop", label="Stop (the confirmation's)", above=1800,
               exact=True):
        check("34: the confirmation's Stop is reachable", False,
              f"visible: {labels(rows)[:10]}")
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




PREF = f"/data/data/{PKG}/shared_prefs/FlutterSharedPreferences.xml"


def kept_record():
    """The app's own record of the video it kept: `{name, uri, keptAt}` per
    content, under `shared_preferences`' key `video_record`.

    This is the name the gallery entry has to bear, read from the app that wrote
    it — the page's own "Video made: …" line names the *file the render wrote*,
    which is the working directory's, and reading that instead would be checking
    the wrong name (SC-001's line is about the file, FR-011's rule is about the
    content)."""
    raw = adb("shell", "run-as", PKG, "cat", PREF).stdout
    m = re.search(r'name="flutter\.video_record"[^>]*>([^<]*)<', raw)
    if not m:
        return None
    # `shared_preferences` escapes the JSON's quotes in the XML.
    text = m.group(1).replace("&quot;", '"').replace("&amp;", "&")
    try:
        entries = json.loads(text)
    except ValueError:
        return None
    return next(iter(entries.values()), None)


def row_33():
    step("33 setup: a fresh install and an empty gallery")
    hard_restart()
    clear_album()
    files_before, entries_before = gallery_videos()
    check("33: the gallery starts without a video of the app's",
          not files_before and not entries_before,
          f"files={files_before} entries={entries_before}")

    # ---- one render, watched, then thrown away --------------------------
    step("33: render a video, and watch it before keeping it")
    first = render("33/first", "16:9 landscape 1080p")
    check("33: the render produced a file", first is not None)
    if not first:
        return
    path, ms, size, frames, wall = first
    rows = dump()
    show(rows, 10)
    check("33: the review offers the three decisions",
          on_screen(rows, "Discard") and on_screen(rows, "Share")
          and on_screen(rows, "Save"), repr(labels(rows)[:10]))
    appsurfaces = surfaces_of()
    check("33: the review's picture is on screen (a surface of its own)",
          bool(appsurfaces), repr(appsurfaces[:4]))

    step("33: play the working copy inside the review")
    if SKIP_PLAY:
        print("   SKIPPED (KLHU_SKIP_PLAY=1): the player is this box's memory "
              "peak and the emulator dies under it")
    else:
        clear_logcat()
        played = play_in_view("33/review", rows)
        check("33: the review's video plays (the phone has its sound running)",
              bool(played), f"started players: {played}")
        errors = [l for l in logcat().splitlines()
                  if PKG in l and ("MediaPlayer" in l or "IllegalState" in l)]
        check("33: playing it reported no error", not errors, repr(errors[:3]))

    step("33: throw this one away")
    if not tap(dump(), "Discard", label="Discard", exact=True):
        return
    time.sleep(2)
    rows = dump()
    check("33: the page is idle again after the throw-away",
          on_screen(rows, "Video") and not on_screen(rows, "Video preview"),
          repr(labels(rows)[:8]))
    files_after, entries_after = gallery_videos()
    check("33: throwing a render away kept nothing in the gallery",
          files_after == files_before and entries_after == entries_before,
          f"files={files_after} entries={entries_after}")

    # ---- another render, kept ------------------------------------------
    step("33: render again and keep it")
    second = render("33/second", "16:9 landscape 1080p")
    check("33: the second render produced a file", second is not None)
    if not second:
        return
    path2, ms2, size2, frames2, wall2 = second
    rows = dump()
    if not tap(rows, "Save", label="Save", exact=True):
        return
    kept_files = wait_for(lambda: gallery_videos()[0], 25)
    kept_entries = gallery_videos()[1]
    print(f"   gallery after keeping: {kept_files} / {kept_entries}")
    record = wait_for(lambda: kept_record() or None, 20)
    name = (record or {}).get("name")
    check("33: the app's own record names the kept video", bool(name),
          repr(record))
    if not name:
        return
    check("33: the name is the content's, not the render's own file",
          name != path2.split("/")[-1],
          f"record name {name!r}, the render wrote {path2.split('/')[-1]!r}")
    check("33: the gallery holds the file the record names",
          f"{name}" in kept_files, f"wanted {name!r} in {kept_files}")
    check("33: the library holds it as a video, under that name",
          f"{name}" in kept_entries, f"entries={kept_entries}")

    dest = os.path.join(OUT, "33_kept.mp4")
    subprocess.run(["adb", "-s", DEV, "pull", f"{ALBUM}/{name}", dest],
                   capture_output=True)
    got = os.path.getsize(dest) if os.path.exists(dest) else 0
    check("33: the kept file came off the device and is the render's own bytes",
          got == size2, f"{got}B pulled, the render wrote {size2}B")
    ok = ffprobe_checks("33/kept", dest, ms2, frames2, 1920, 1080)
    check("33: the kept video's own streams parse", ok)

    rows = dump()
    check("33: the content now offers the video's own actions",
          on_screen(rows, "Play video") and on_screen(rows, "Delete video"),
          repr(labels(rows)[:10]))

    step("33: play the kept video, from the gallery's own entry")
    if SKIP_PLAY:
        print("   SKIPPED (KLHU_SKIP_PLAY=1), and so is opening its screen")
    elif tap(rows, "Play video", label="the content's play"):
        time.sleep(2.5)
        played = play_in_view("33/kept", dump())
        check("33: the kept video plays", bool(played), f"started players: {played}")
        adb("shell", "input", "keyevent", "4")   # back to the page
        time.sleep(1.5)

    step("33: share it — the phone's own list, and nothing kept by sharing")
    files_shared, entries_shared = gallery_videos()
    rows = dump()
    if not tap(rows, "Share", label="Share"):
        return
    # The phone's chooser is another app's window and animates in: a dump taken
    # while it is still coming up holds nothing at all, which reads as "no list
    # appeared" when the list is right there a moment later.
    shown = []
    for _ in range(6):
        time.sleep(2)
        shown = labels(dump())
        if shown:
            break
    print(f"   share sheet: {shown[:12]}")
    if not shown:
        # An empty dump is not "no list": whatever is up holds nothing the
        # accessibility service can name. The classes are what say what it is.
        print("   nothing nameable is up; the raw tree holds:",
              [(n["cls"], n["id"], n["desc"][:20], n["w"], n["h"])
               for n in raw_nodes()][:8])
    check("33: the phone's own share list appeared",
          any("share" in l.lower() for l in shown) or len(shown) > 3,
          repr(shown[:12]))
    files_now, entries_now = gallery_videos()
    check("33: sharing kept nothing new and removed nothing",
          files_now == files_shared and entries_now == entries_shared,
          f"files={files_now} entries={entries_now}")
    adb("shell", "input", "keyevent", "4")
    time.sleep(1.5)

    step("33: delete it, behind its warning")
    rows = dump()
    if not tap(rows, "Delete video", label="Delete video"):
        return
    time.sleep(2)
    rows = dump()
    check("33: deleting warns first",
          on_screen(rows, "Delete this video?")
          and on_screen(rows, "removed from your gallery"),
          repr(labels(rows)[:8]))
    if not tap(rows, "Cancel", label="Cancel", exact=True):
        return
    time.sleep(1.5)
    still = gallery_videos()[0]
    check("33: cancelling the warning deletes nothing", still == files_shared,
          f"files={still}")

    rows = dump()
    if not tap(rows, "Delete video", label="Delete video"):
        return
    time.sleep(2)
    rows = dump()
    if not tap(rows, "Delete", label="Delete (the dialog's)", exact=True):
        return
    gone = wait_for(lambda: not gallery_videos()[0], 25)
    check("33: the gallery no longer lists the file", gone,
          f"files={gallery_videos()[0]}")
    entries = gallery_videos()[1]
    check("33: the library has no entry for it either", not entries,
          f"entries={entries}")
    rows = dump()
    check("33: the content offers to record again, and nothing else",
          on_screen(rows, "Video") and not on_screen(rows, "Play video")
          and not on_screen(rows, "Delete video"),
          repr(labels(rows)[:10]))



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
        # A review left up from the previous aspect hides the page's own toolbar,
        # and then this row reads "the render produced no file" for a render it
        # never started. This row keeps nothing, so taking it down is its own.
        rows = dump()
        if on_screen(rows, "Discard") and tap(rows, "Discard", label="the earlier review"):
            time.sleep(1.5)
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
ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
APK = os.path.join(ROOT, "build", "app", "outputs", "flutter-apk", "app-debug.apk")

# The playback steps are the memory peak of this walk (a platform view plus the
# video's own player), and this development box kills the emulator under it. With
# this set, the steps are skipped and *said* to be skipped — the rest of the row
# (keep, share, delete) still runs, and the gap is on the record rather than
# papered over.
SKIP_PLAY = os.environ.get("KLHU_SKIP_PLAY") == "1"


def preflight():
    """The walk is only as good as the device it runs on.

    Two failures look exactly like the app behaving oddly and cost a whole run:
    an emulator that is not there (this box kills it under the render's memory
    peak), and an app older than the APK on disk (an AVD snapshot restores last
    week's build, and then the walk drives a version nobody is working on)."""
    devices = adb("devices").stdout
    if DEV not in devices or "offline" in devices:
        print(f"{DEV} is not available.\n"
              "  start it first:  emulator -avd klhu -no-window")
        sys.exit(2)
    if os.path.exists(APK):
        built = time.strftime("%Y-%m-%d %H:%M:%S",
                              time.localtime(os.path.getmtime(APK)))
        m = re.search(r"lastUpdateTime=(\S+)",
                      adb("shell", "dumpsys", "package", PKG).stdout)
        if m and m.group(1) < built:
            print(f"the app on {DEV} is older than the APK built at {built}\n"
                  f"  device has {m.group(1)} — install it first:\n"
                  f"  adb install -r {os.path.relpath(APK, ROOT)}")
            sys.exit(2)


# --------------------------------------------------------------------------
# The reader's own pictures on the device (row 49). The row brings its own
# pictures, chooses them through the platform's own **file dialog** — driven
# from here, which is what makes this row unattended — and then reads the
# frames of a real render for what each range carries.

PICTURE_DIR = "/sdcard/Pictures/klhu_walk"


def row_pictures():
    """The pictures this row pushes: (name, rgb, band rgb or None, the ink).

    The ink is what a frame gives away: the plate is the tone's own colour (the
    words read in its opposite), so over a light picture the ink is black and
    over a dark one it is white — the reader's own two cases from the phone
    ('white text black background, black text white background. all works.').

    Every colour here is unambiguous under any tone threshold between 0.1 and
    0.8: the light ones are near-white and the dark ones are near-black, so the
    check does not depend on where the app draws its own line. **kw02** is the
    one that matters most: dark all over, with a **bright band under the words**,
    so its band tone and its average tone disagree — D16's own case. If the app
    plated by the picture's average, kw02's ink would be white and this row would
    say so.
    """
    return [
        ("kw00.png", (255, 255, 255), None, (0, 0, 0)),          # a white picture
        ("kw01.png", (0, 0, 0), None, (255, 255, 255)),          # a black picture
        # kw02's bright band is where the words land — the bottom of the text
        # area since 2026-09-28 — which is the picture's own y 340..470 once the
        # cover crop into a 16:9 frame is accounted for.
        ("kw02.png", (40, 40, 40), (255, 255, 255), (0, 0, 0)),  # dark, bright band
        ("kw03.png", (255, 240, 200), None, (0, 0, 0)),
        ("kw04.png", (60, 30, 30), None, (255, 255, 255)),
        ("kw05.png", (200, 255, 200), None, (0, 0, 0)),
        ("kw06.png", (30, 60, 30), None, (255, 255, 255)),
        ("kw07.png", (255, 200, 255), None, (0, 0, 0)),
        ("kw08.png", (30, 30, 60), None, (255, 255, 255)),       # the ninth: over the count
    ]


def make_pictures():
    """Writes the row's pictures to $OUT/pics and answers their paths.

    kw02's bright band is placed where the render's own text column will land:
    a 3:4 picture in a 16:9 frame is cropped to the picture's middle, and the
    column's first line sits just inside that, so the band spans the picture's
    own x 105..375 (the column's x, once scaled) and y 200..400.
    """
    out = os.path.join(OUT, "pics")
    os.makedirs(out, exist_ok=True)
    paths = []
    for name, rgb, band, _ink in row_pictures():
        path = os.path.join(out, name)
        colour = "0x%02x%02x%02x" % rgb
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-f", "lavfi",
               "-i", f"color=c={colour}:s=480x640", "-frames:v", "1"]
        if band:
            band_colour = "0x%02x%02x%02x" % band
            # The picture's own x 105..375 is the column's x once the 3:4 picture
            # is scaled to a 16:9 frame (×4); its y 340..470 is the column's lower
            # part once the vertical crop is accounted for. Both follow from the
            # painter's own geometry — see the walk's `column_of`.
            cmd += ["-vf", f"drawbox=x=105:y=405:w=270:h=30"
                           f":color={band_colour}:t=fill"]
        subprocess.run(cmd + [path], check=True)
        paths.append(path)
    print(f"   {len(paths)} pictures written, e.g. {os.path.basename(paths[0])}")
    return paths


def push_pictures(paths):
    """Pushes them into the device's Pictures/ and asks the gallery to look."""
    adb("shell", "mkdir", "-p", PICTURE_DIR)
    adb("push", *paths, PICTURE_DIR + "/")
    for path in paths:
        name = os.path.basename(path)
        adb("shell", "am", "broadcast",
            "-a", "android.intent.action.MEDIA_SCANNER_SCAN_FILE",
            "-d", f"file://{PICTURE_DIR}/{name}")
    time.sleep(2)
    listing = adb("shell", "ls", PICTURE_DIR).stdout.split()
    check("49: the row's own pictures are on the device",
          len(listing) >= len(paths), f"{len(listing)} files in {PICTURE_DIR}")


def choose_pictures(names):
    """Chooses [names] in the platform's own file dialog, in this order.

    The dialog is the system's Files app in its Recent view. A **long press** on
    the first name is what starts its selection mode — the toolbar then reads
    'N selected' and carries the button that confirms, 'Select' — then one tap
    per other name, then that button, which hands the files back to the app.
    """
    rows = dump()
    first = find(rows, names[0])
    if not first:
        check(f"49: the dialog shows {names[0]}", False,
              f"offered: {[l for l in labels(rows) if '.png' in l][:6]}")
        return False
    row = first[0]
    adb("shell", "input", "swipe", str(row["x"]), str(row["y"]),
        str(row["x"]), str(row["y"]), "900")
    print(f"   long press on {names[0]} @{row['x']},{row['y']} "
          "(this is what opens selection mode)")
    time.sleep(1.5)
    rows = dump()
    for name in names[1:]:
        if not tap(rows, name, label=name):
            return False
        time.sleep(0.8)
        rows = dump()
    print("   the dialog says:",
          [l for l in labels(rows) if l.endswith("selected")])
    for label in ("Select", "Open", "Done"):
        if tap(rows, label, label=f"the dialog's own {label}"):
            break
    else:
        check("49: the dialog offers a way to confirm", False,
              f"visible: {labels(rows)[:12]}")
        return False
    time.sleep(3)
    return True


def cache_entries():
    """The app's own working entries (`picks_*`, `render_*`), by name: what
    SC-024 says must not outlive the prompt and the render that used it."""
    names = []
    for path in shell_files(CACHE).split():
        base = os.path.basename(path)
        if base.startswith("picks_") or base.startswith("render_"):
            names.append(base)
    return sorted(names)


def off_column(w, h):
    """Points outside the text column (frame coordinates): where only the
    picture itself can be, if a picture is there at all.

    Derived from the column itself rather than from fixed fractions of the frame:
    the column's width follows the painter's rule, and a sample point that was
    outside a 1080-wide column is inside a 1512-wide one. Six points around it —
    both ends of the middle, the middle of the top and the bottom, and the two
    upper/lower corners of the frame."""
    left, top, col_w = column_of(w, h)
    return [(left / 2.0, 0.5 * h), (w - left / 2.0, 0.5 * h),
            (left / 2.0, h - top / 2.0), (w - left / 2.0, h - top / 2.0),
            (0.5 * w, top / 2.0), (0.5 * w, top / 4.0)]


def picture_at(rgb, w, h, pictures, tol=24):
    """Which of the row's pictures fills this frame, or None: the frame's
    pixels outside the column are the picture's own colour (FR-027's 'the
    picture fills the frame'), so they name it."""
    for x, y in off_column(w, h):
        px = at(rgb, w, int(x), int(y))
        # The **nearest** of the row's own colours, not the first within reach:
        # two of them (a dark grey and a dark red) are close enough that a loose
        # match names the wrong picture, and then every check about it is a
        # check about the wrong picture.
        best, best_d = None, None
        for name, colour, _band, _ink in pictures:
            d = sum((a - b) ** 2 for a, b in zip(px, colour))
            if best_d is None or d < best_d:
                best, best_d = name, d
        if best_d is not None and best_d <= tol * tol * 3:
            return best
        return None
    return None


def ink_in_column(rgb, w, h, colour):
    """(count, box) of one ink colour inside the text column, sampled every other
    pixel.

    One colour rather than both: a solid white picture is near-white through the
    whole column and a solid black one is near-black, so counting both makes the
    picture itself the biggest pile of "ink" and the box the whole column. The
    colour asked for is the one the words are read in over *this* picture, which
    the row knows from the picture's own band — and its box is where the words
    are, which is what says the block sits at the bottom of the frame since the
    reader's own request of 2026-09-28.
    """
    left, top, col_w = column_of(w, h)
    near_white = colour == (255, 255, 255)
    count = 0
    box = None
    for y in range(int(top), int(h - top), 2):
        for x in range(int(left), int(left + col_w), 2):
            px = at(rgb, w, x, y)
            hit = (all(c >= 240 for c in px) if near_white
                   else all(c <= 15 for c in px))
            if not hit:
                continue
            count += 1
            box = (x, y, x, y) if box is None else (
                min(box[0], x), min(box[1], y), max(box[2], x), max(box[3], y))
    return count, box


def row_49():
    step("49: the row's own pictures, pushed into the device's Pictures/")
    hard_restart()
    sentences = preset_sentences()
    print(f"   the pre-set's {len(sentences)} sentences")
    before = cache_entries()
    print(f"   the app's own working entries before anything: {before}")
    push_pictures(make_pictures())
    pictures = row_pictures()

    # ---- the choice over the count (FR-026's re-cut from the phone) ----
    step("49: five pictures, then five more through Choose more — one over the count")
    rows = dump()
    if on_screen(rows, "Discard") and tap(rows, "Discard", label="an earlier review"):
        time.sleep(1.5)
        rows = dump()
    if not tap(rows, "Video", label="the video action"):
        return
    time.sleep(1.5)
    rows = dump()
    if not tap(rows, "16:9 landscape", label="the landscape format"):
        return
    time.sleep(0.6)
    rows = dump()
    if not tap(rows, "Choose pictures", label="Choose pictures"):
        return
    time.sleep(3)
    if not choose_pictures([p[0] for p in pictures[:5]]):
        return
    rows = dump()
    check("49: the first five are on the page",
          on_screen(rows, "5 pictures chosen"), f"visible: {labels(rows)[:8]}")
    if not tap(rows, "Choose more", label="Choose more"):
        return
    time.sleep(3)
    if not choose_pictures([p[0] for p in pictures[5:9]]):
        return
    rows = dump()
    check("49: Choose more adds to the choice rather than replacing it",
          on_screen(rows, "9 pictures chosen"), f"visible: {labels(rows)[:8]}")
    check("49: a choice one over the count is said nothing about",
          not any("sentence" in (r["desc"] or r["text"]).lower() for r in rows),
          "no label mentions the video's sentences")
    start = find(rows, "Start")
    check("49: and the render is offered as it stands",
          bool(start) and start[0]["enabled"],
          "Start is there and enabled — nothing to take back first")
    if tap(rows, "Cancel", label="Cancel"):
        time.sleep(1.5)
    after_cancel = cache_entries()
    check("49: a cancelled prompt leaves nothing behind (SC-024)",
          after_cancel == before,
          f"after the cancel: {after_cancel} (before: {before})")

    # ---- the render, and what each of its ranges carries ----
    step("49: eight pictures for eight sentences, rendered, frame by frame")
    rows = dump()
    if not tap(rows, "Video", label="the video action"):
        return
    time.sleep(1.5)
    rows = dump()
    if not tap(rows, "16:9 landscape", label="the landscape format"):
        return
    time.sleep(0.6)
    rows = dump()
    if not tap(rows, "Choose pictures", label="Choose pictures"):
        return
    time.sleep(3)
    if not choose_pictures([p[0] for p in pictures[:8]]):
        return
    rows = dump()
    check("49: all eight are on the page, one cell each",
          on_screen(rows, "8 pictures chosen"), f"visible: {labels(rows)[:8]}")
    result = render("49", None)
    if not result:
        check("49: the render produced a file", False)
        return
    path, ms, size, frames, wall = result
    dest = os.path.join(OUT, "49_pictures.mp4")
    data, pulled = pull(path, dest)
    check("49: the file came off the device and is not empty",
          pulled and len(data) > 10000, f"{len(data)}B, {frames} frames")

    # What each frame shows outside the column names the picture it belongs to.
    coarse = coarse_frames(dest)
    print(f"   {len(coarse)} frames at {CW}x{CH}, looking for the pictures")
    runs = []
    for number, frame in enumerate(coarse):
        name = picture_at(frame, CW, CH, pictures, tol=30)
        if name and runs and runs[-1][0] == name:
            runs[-1][1] = number
        elif name:
            runs.append([name, number, number])
    drawn = [name for name, _a, _b in runs]
    print(f"   the ranges the pictures cover: {drawn}")
    check("49: every sentence's own run carries a picture, once each",
          sorted(drawn) == sorted(p[0] for p in pictures[:8]),
          f"drawn: {drawn}")
    check("49: the ninth picture — the one over the count — is drawn nowhere",
          pictures[8][0] not in drawn, f"{pictures[8][0]} appears in no range")

    by_name = {p[0]: p for p in pictures}
    for name, start, end in runs:
        _n, colour, band, ink = by_name[name]
        middle = (start + end) // 2
        rgb = frame_rgb(dest, middle, 1920, 1080)
        if rgb is None:
            check(f"49/{name}: frame {middle} read", False, "ffmpeg gave nothing")
            continue
        outside = [at(rgb, 1920, int(x), int(y))
                   for x, y in off_column(1920, 1080)]
        check(f"49/{name}: the picture fills the frame — no bars, no letterbox",
              all(all(abs(a - b) <= 16 for a, b in zip(px, colour))
                  for px in outside),
              f"outside the column: {outside[:3]}")
        want = "white" if ink == (255, 255, 255) else "black"
        count, box = ink_in_column(rgb, 1920, 1080, ink)
        check(f"49/{name}: the words' ink is {want} (the band's own opposite)",
              count >= 20,
              f"{count} {want} pixels inside the column"
              + (" — the bright band under the words, not the picture's average"
                 if band else ""))
        _left, margin, _w = column_of(1920, 1080)
        check(f"49/{name}: the words sit at the bottom of the frame",
              box is not None
              # The box is the **glyphs'** own, so its bottom sits inside the last
              # line's box by up to a descender's height; what the check is about
              # is that the words are at the bottom rather than at the top, which
              # the upper-half condition settles on its own.
              and abs(box[3] - (1080 - margin)) <= 24
              and box[1] > 1080 / 2,
              f"the words' own box is {box} — the column's bottom is "
              f"{1080 - margin:.0f} — so the picture has the frame above them "
              f"(FR-029, the reader's own request of 2026-09-28)")

    # ---- and the review taken down keeps nothing (SC-024) ----
    rows = dump()
    for label in ("Discard", "Keep"):
        if on_screen(rows, label) and tap(rows, label, label=f"the review's {label}"):
            time.sleep(2)
            break
    rows = dump()
    if on_screen(rows, "Delete"):
        tap(rows, "Delete", label="the warning's own Delete")
        time.sleep(2)
    after_render = cache_entries()
    check("49: nothing the reader chose outlives the prompt (SC-024)",
          after_render == before,
          f"after the render: {after_render} (before: {before})")


def main():
    if len(sys.argv) < 2 or sys.argv[1] not in ("31", "32", "33", "34", "49"):
        print(__doc__)
        sys.exit(2)
    row = sys.argv[1]
    os.makedirs(OUT, exist_ok=True)
    print(f"klhu walk 012 row {row} — device {DEV}, package {PKG}, out {OUT}")
    if not shutil.which("ffprobe") or not shutil.which("ffmpeg"):
        print("ffprobe and ffmpeg are required for this row")
        sys.exit(2)
    preflight()
    {"31": row_31, "32": row_32, "33": row_33, "34": row_34,
     "49": row_49}[row]()

    print("\n===== result =====")
    failed = [r for r in RESULTS if not r[1]]
    for name, ok, detail in RESULTS:
        print(f"  {'PASS' if ok else 'FAIL'}  {name}"
              f"{(' — ' + detail) if detail else ''}")
    print(f"\n{len(RESULTS) - len(failed)}/{len(RESULTS)} checks passed")
    sys.exit(1 if failed else 0)


if __name__ == "__main__":
    main()
