#!/usr/bin/env python3
"""klhu device walk — 023 quickstart rows 9–14.

Row 9:  a real render's picture moves, stays inside the bound, and no frame shows
        the background (FR-001, FR-005, FR-013, SC-002).
Row 10: the drift is gentle and the framing rests at least once every 8 s
        (SC-003).
Row 11: the plate keeps its colour while the band drifts (A4).
Row 12: the effect-on render's wall time, against SC-005's ceiling (probe P1).
Row 13: off and on, one content: what the effect does not change, and the ratio.
Row 14: with the switch off, two renders are frame-for-frame the same and, when
        a list is handed in via `KLHU_BASE_FRAMEMD5`, the same as `0ef44e7`'s
        build (SC-001, FR-011). `14base` is the half that runs against that
        pre-feature build, which has no motion row at all.

The mechanics are 012's (`specs/012-reading-video/scripts/klhu_walk_video.py`):
one string per `adb shell` command, `uiautomator dump` reads, `check(name, ok,
detail)` with a PASS/FAIL summary and a non-zero exit, `preflight` which refuses
a device older than the APK on disk, the library's own seeding, the platform's
own file dialog for the reader's pictures, and `frame_rgb` for a frame's exact
pixels. 023 adds only what is its own: the four-quadrant fixture whose colour
boundaries sit **off centre** (a quarter across, a third down) so a pan and a
zoom both move them, the switch's own tap and read, the parser for the render's
`klhu render motion … dirs=…` line, and the marker arithmetic below.

Usage:  /usr/bin/python3 -u klhu_walk_motion.py 9
        ADB_SERIAL=emulator-5554 /usr/bin/python3 -u klhu_walk_motion.py 9
Artifacts land in $KLHU_OUT (default /tmp/klhu_out) — never in the repository.
"""
import json
import os
import re
import struct
import sys
import time
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(REPO, "specs", "012-reading-video", "scripts"))
sys.path.insert(0, os.path.join(REPO, "specs", "020-sentence-pictures", "scripts"))

import klhu_walk_video as video  # noqa: E402
import klhu_walk_assignment as assignment  # noqa: E402  (the library's own seed)

OUT = video.OUT
PKG = video.PKG
DEV = video.DEV

# The fixture's own shape: a 4:3 photo, so its cover crop in the 16:9 frame is
# 4032×2268 and the inset framing is 3360×1890.
PIC_W, PIC_H = 4032, 3024
QUARTER_X = PIC_W // 4
THIRD_Y = PIC_H // 3
# The reader's two sentences, one picture over both.
CONTENT = ("The river runs under the old bridge, quiet and slow. "
           "Morning light on the water, and the town waking behind it.")
NAME = "Motion"
RED = (255, 0, 0)
GREEN = (0, 255, 0)
BLUE = (0, 0, 255)
YELLOW = (255, 255, 0)
BG = (0x10, 0x10, 0x14)
PICTURE = "motion_quadrants.png"
PICTURE_FOR_ROW = {}


def chunk(tag, data):
    return (struct.pack(">I", len(data)) + tag + data +
            struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))


def png(path):
    """The four-quadrant picture, written by hand (020's own shape: `struct` +
    `zlib`, no imaging library on the walking box)."""
    rows = []
    for y in range(PIC_H):
        row = bytearray(b"\x00")
        for x in range(PIC_W):
            if x < QUARTER_X:
                rgb = RED if y < THIRD_Y else BLUE
            else:
                rgb = GREEN if y < THIRD_Y else YELLOW
            row.extend(rgb)
        rows.append(bytes(row))
    raw = b"".join(rows)
    ihdr = struct.pack(">IIBBBBB", PIC_W, PIC_H, 8, 2, 0, 0, 0)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
                     chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    return path


def png_two_bands(path, split_fraction=0.71):
    """Dark above, light below, with the boundary where the words' band sits when
    the inset framing maps the picture onto the frame (row 11).

    The words rest near the bottom of a landscape frame; at the inset framing
    (top 567, height 1890 in the picture's own pixels) a frame row of ~900 maps
    to picture row ~2142, which is 71 % of 3024 — so the boundary is put there.
    """
    split = int(PIC_H * split_fraction)
    rows = []
    for y in range(PIC_H):
        rgb = (0x22, 0x22, 0x28) if y < split else (0xE6, 0xE0, 0xD6)
        rows.append(b"\x00" + bytes(rgb) * PIC_W)
    raw = b"".join(rows)
    ihdr = struct.pack(">IIBBBBB", PIC_W, PIC_H, 8, 2, 0, 0, 0)
    with open(path, "wb") as handle:
        handle.write(b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) +
                     chunk(b"IDAT", zlib.compress(raw, 6)) + chunk(b"IEND", b""))
    return path


BANDS = "motion_bands.png"


def fixture():
    directory = os.path.join(OUT, "pics_023")
    os.makedirs(directory, exist_ok=True)
    path = png(os.path.join(directory, PICTURE))
    png_two_bands(os.path.join(directory, BANDS))
    return path


CONTENT_ID = "motion_023"


def seed():
    """Puts this row's two-sentence content in the library and opens it.

    020's own `seed_content` is the shape (fresh prefs, the content file, the
    index entry, force-stop, start): the index is the library's own file, so the
    app is restarted after the write and what the row renders is the file. Fresh
    prefs also clear 023's own choice, which is what a row wants to start from.
    """
    assignment.fresh_prefs()
    directory = f"{assignment.LIBRARY}/content"
    assignment.adb("shell", "run-as", assignment.PKG, "mkdir", "-p",
                   f"{directory}/contents")
    if not assignment.device_write(f"{directory}/contents/{CONTENT_ID}.txt",
                                   CONTENT.encode()):
        video.check("the content is in the library", False, "the write failed")
        return False
    index = json.loads(assignment.cat(assignment.INDEX).decode())
    stamp = time.strftime("%Y-%m-%dT%H:%M:%S.000000Z", time.gmtime())
    index["entries"] = [e for e in index["entries"]
                        if e["id"] != CONTENT_ID] + [{
        "id": CONTENT_ID, "name": NAME, "language": "en", "origin": "user",
        "createdAt": stamp, "updatedAt": stamp, "charCount": len(CONTENT),
    }]
    index["lastOpenedId"] = CONTENT_ID
    if not assignment.device_write(assignment.INDEX,
                                   json.dumps(index).encode()):
        video.check("the library index carries it", False, "the index write")
        return False
    assignment.adb("shell", "am", "force-stop", assignment.PKG)
    assignment.start_app()
    return True


def open_preset():
    """Opens the app's own shipped pre-set — 012's row 36 fixture, 17 sentences —
    by pointing the library's own `lastOpenedId` at it (020's own id for it)."""
    assignment.fresh_prefs()
    index = json.loads(assignment.cat(assignment.INDEX).decode())
    index["lastOpenedId"] = "preset_en_sample"
    if not assignment.device_write(assignment.INDEX,
                                   json.dumps(index).encode()):
        video.check("12: the preset is the open content", False, "index write")
        return False
    assignment.adb("shell", "am", "force-stop", assignment.PKG)
    assignment.start_app()
    return True


def leave_review():
    """Back to the content from the post-render review.

    The review is a screen of its own: Discard, then the confirm it asks for if
    it asks. The page beneath it still carries the video action in the dump, so
    the test is the **review's own labels** — not whether 'Video' is anywhere in
    the tree.
    """
    rows = video.dump()
    if not video.on_screen(rows, "Discard"):
        return True
    if not video.tap(rows, "Discard", label="the review's Discard"):
        return False
    time.sleep(2.0)
    rows = video.dump()
    for label in ("Discard", "Delete", "Confirm", "OK"):
        if video.tap(rows, label, label=f"the confirm's {label}"):
            time.sleep(2.0)
            return True
    return True


def open_prompt(where):
    video.clear_logcat()
    rows = video.dump()
    if not video.tap(rows, "Video", label="the video action"):
        return False
    time.sleep(1.5)
    rows = video.dump()
    ok = video.on_screen(rows, "Video format")
    video.check(f"{where}: the prompt opened", ok,
                f"visible: {video.labels(rows)[:8]}")
    return ok


def switch_present(rows):
    """Whether the prompt shows the motion row at all (FR-009's surface).

    The row's own value is not read back from the dump: a Flutter switch's
    semantics are not the platform's checked attribute on every engine build, and
    the value that matters is proved twice over — the page's own unit case
    (`test/reading_view_video_motion_test.dart`) and, here, the render's own
    `klhu render motion` line, which exists only if the answer reached it.
    """
    for node in rows:
        labels = video.labels([node])
        if labels and "moves gently" in labels[0]:
            return node
    return None


def tap_switch(node):
    video.adb("shell", "input", "tap", str(node["x"]), str(node["y"]))
    print(f"   tap 'the motion switch' @{node['x']},{node['y']}")
    time.sleep(0.6)
    return True


def render(where, motion, with_picture=True, switch_required=True):
    """Opens the prompt, sets the switch, picks the picture and renders.

    `switch_required=False` is for `14base` only: the pre-feature build has no
    motion row at all, and that absence is the difference the row is measuring,
    so the missing row is the expected state there rather than a failure.

    Answers (path, ms, bytes, frames, wall) — the same record 012's own
    `render()` answers — or None."""
    if not open_prompt(where):
        return None
    rows = video.dump()
    node = switch_present(rows)
    if node is None:
        if switch_required or motion:
            video.check(f"{where}: the prompt offers the motion switch", False,
                        f"visible: {video.labels(rows)[:12]}")
            return None
        print(f"   {where}: no motion row on this build — off is the only state")
    else:
        video.check(f"{where}: the prompt offers the motion switch", True)
    # `seed()` cleared the device's prefs, so the row opens off and one tap is
    # what turns it on — and the render's own motion line is what proves the
    # answer reached the renderer.
    if motion:
        tap_switch(node)
    if with_picture:
        if not video.tap(rows, "Choose pictures", label="Choose pictures"):
            return None
        time.sleep(2.5)
        # The dialog opens where it was left: scrolled down past the alphabet's
        # start, where this row's own picture is. Three drags put it back at the
        # top (a finger down moves the list up), so the walk sees the first
        # entries rather than whichever ones the last row left on screen.
        for _ in range(3):
            video.adb("shell", "input", "swipe", "540", "700", "540", "1900",
                      "200")
            time.sleep(0.5)
        if not video.choose_pictures([PICTURE_FOR_ROW.get(where, PICTURE)]):
            video.check(f"{where}: the picture was chosen", False)
            return None
        video.check(f"{where}: the picture was chosen", True)
    rows = video.dump()
    if not video.tap(rows, "Start", label="Start"):
        return None
    started = time.time()
    done = None
    while time.time() - started < video.RENDER_TIMEOUT:
        m = re.search(r"klhu render done: (\S+) (\d+)ms (\d+)B frames=(\d+)",
                      video.logcat())
        if m:
            done = (m.group(1), int(m.group(2)), int(m.group(3)), int(m.group(4)))
            break
        time.sleep(0.5)
    wall = time.time() - started
    if not done:
        video.check(f"{where}: the render reported done", False,
                    f"nothing within {video.RENDER_TIMEOUT}s")
        print("   logcat tail:")
        for line in video.logcat().splitlines()[-20:]:
            print("     ", line.strip())
        return None
    path, ms, size, frames = done
    video.check(f"{where}: the render reported done", True,
                f"{wall:.0f}s wall, {frames} frames")
    local = os.path.join(OUT, f"motion_{where}.mp4")
    video.pull(path, local)
    return local, ms, size, frames, wall


def motion_line():
    m = re.search(r"klhu render motion picture=(\d+) frames=(\d+)\.\.(\d+) "
                  r"cycles=(\d+) dirs=(\S+)", video.logcat())
    if not m:
        return None
    cycles = []
    for item in m.group(5).split(","):
        name, _, px = item.partition(":")
        cycles.append((name, int(px)))
    return {
        "picture": int(m.group(1)),
        "first": int(m.group(2)),
        "last": int(m.group(3)),
        "cycles": cycles,
    }


def frame_and_markers(file, number, w, h):
    """One frame, and where its two colour boundaries landed: (column, row)."""
    rgb = video.frame_rgb(file, number, w, h)
    if rgb is None:
        return None, None, None
    # The top row's first non-red pixel is the picture's vertical boundary.
    column = None
    for x in range(1, w):
        px = video.at(rgb, w, x, max(2, h // 20))
        if abs(px[0] - RED[0]) > 8 or abs(px[1] - RED[1]) > 8:
            column = x
            break
    # The left column's first non-red pixel is its horizontal boundary.
    row = None
    for y in range(1, h):
        px = video.at(rgb, w, max(2, w // 100), y)
        if abs(px[0] - RED[0]) > 8 or abs(px[1] - RED[1]) > 8:
            row = y
            break
    return rgb, column, row


def edge_background_pixels(rgb, w, h, band=8):
    """Background-coloured pixels **along the frame's four edges**.

    A gap where the picture should be shows at an edge, never in the middle of
    the frame — and a text glyph's antialiasing can land on the background's own
    colour by chance, which is why the count is scoped to the band the words
    never reach (012's own `off_column` reasoning)."""
    count = 0
    for y in list(range(0, band)) + list(range(h - band, h)):
        for x in range(0, w, 2):
            if video.is_bg(video.at(rgb, w, x, y), BG):
                count += 1
    for x in list(range(0, band)) + list(range(w - band, w)):
        for y in range(band, h - band, 2):
            if video.is_bg(video.at(rgb, w, x, y), BG):
                count += 1
    return count


def row_9(file, frames, w, h):
    print("\nrow 9 — the picture moves, inside the bound, and never a gap")
    motion = motion_line()
    if not motion:
        video.check("9: the render printed its motion line", False,
                    "no 'klhu render motion' line in the log")
        return
    video.check("9: the render printed its motion line", True,
                f"picture={motion['picture']} frames={motion['first']}.."
                f"{motion['last']} cycles={len(motion['cycles'])}")
    first, last = motion["first"], motion["last"]
    columns, rows_, gaps = [], [], []
    for number in range(first, min(last + 1, frames), 3):
        rgb, column, row = frame_and_markers(file, number, w, h)
        if column is None or row is None:
            continue
        columns.append(column)
        rows_.append(row)
        gaps.append(edge_background_pixels(rgb, w, h))
    if not columns:
        video.check("9: frames carried the picture", False)
        return
    # The bound, in the frame's own pixels: a tenth of the frame's own width and
    # height (192 and 108 at 1920×1080), read as each frame's **displacement from
    # the framing at rest** — the inset crop puts the markers at 384 and 252, and
    # a pan travels cap in *both* directions from there, so the samples' span is
    # twice the bound and the displacement is the bound.
    off_x = max(abs(c - 384) for c in columns)
    off_y = max(abs(r - 252) for r in rows_)
    video.check("9: no frame's boundary sat beyond the frame's tenth across",
                off_x <= w // 10 + 4, f"worst {off_x} px of {w // 10}")
    video.check("9: no frame's boundary sat beyond the frame's tenth down",
                off_y <= h // 10 + 4, f"worst {off_y} px of {h // 10}")
    video.check("9: the picture moved at all",
                max(columns) > min(columns) or max(rows_) > min(rows_),
                f"across {min(columns)}..{max(columns)}, "
                f"down {min(rows_)}..{max(rows_)}")
    video.check("9: no frame showed the background along its own edges",
                max(gaps) == 0, f"worst sample {max(gaps)} background pixels")
    video.check("9: the resting framing is the inset one, not the cover crop",
                min(columns) <= 390 <= max(columns) or
                min(rows_) <= 256 <= max(rows_),
                f"columns {min(columns)}..{max(columns)}, "
                f"rows {min(rows_)}..{max(rows_)} (inset 384/252, cover 480/300)")


def coarse_frames_of(file, w=480, h=270):
    """Every frame at 480×270, in one decode: cheap enough to look at all of
    them, sharp enough to place a colour boundary to ±1 scaled pixel (±4 on the
    frame's own 1920)."""
    import subprocess
    out = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", file,
         "-vf", f"scale={w}:{h}:flags=area",
         "-f", "rawvideo", "-pix_fmt", "rgb24", "-"],
        capture_output=True)
    step = w * h * 3
    data = out.stdout
    return [data[i:i + step] for i in range(0, len(data) - step + 1, step)], w, h


def marker_in(frame, w, h):
    """(column, row) of the picture's two colour boundaries, in this frame's own
    pixels — the same scan row 9 makes, on a scaled frame."""
    column = None
    for x in range(1, w):
        px = video.at(frame, w, x, max(1, h // 20))
        if abs(px[0] - RED[0]) > 12 or abs(px[1] - RED[1]) > 12:
            column = x
            break
    row = None
    for y in range(1, h):
        px = video.at(frame, w, max(1, w // 100), y)
        if abs(px[0] - RED[0]) > 12 or abs(px[1] - RED[1]) > 12:
            row = y
            break
    return column, row


def band_and_plate(rgb, w, h):
    """The plate's own colour, and the picture's mean brightness in the words' band.

    The words rest in the lower part of a landscape frame (012's anchor), so the
    band is the frame's lower half. The plate is one of the painter's two pure
    colours — the most common near-white or near-black inside the band — and the
    mean is taken over the band's other pixels, which is the picture showing
    through. Answers (plate, mean), or (None, None) when no plate was found.
    """
    white = black = others = 0
    brightness = 0.0
    for y in range(int(h * 0.58), int(h * 0.90), 3):
        for x in range(int(w * 0.10), int(w * 0.90), 3):
            px = video.at(rgb, w, x, y)
            if all(c >= 240 for c in px):
                white += 1
            elif all(c <= 15 for c in px):
                black += 1
            else:
                brightness += (px[0] + px[1] + px[2]) / 3.0
                others += 1
    plate = None
    if white or black:
        plate = (255, 255, 255) if white >= black else (0, 0, 0)
    return plate, (brightness / others if others else 0.0)


def row_11(file, motion, w, h):
    print("\nrow 11 — the plate over a drifted band (probe P2)")
    first, last = motion["first"], motion["last"]
    # The cycle's own base and its peak: u = 0 and u = 0.5 of a 72-frame cycle.
    picks = (("base", first), ("peak", min(first + 36, last)))
    shots = {}
    for name, number in picks:
        rgb = video.frame_rgb(file, number, w, h)
        if rgb is None:
            video.check(f"11: frame {number} was read", False)
            return
        plate, mean = band_and_plate(rgb, w, h)
        shots[name] = (plate, mean)
        print(f"   {name} frame {number}: plate={plate} band mean={mean:.1f}")
    video.check("11: both frames carry a plate",
                None not in (shots["base"][0], shots["peak"][0]))
    video.check("11: the plate's colour did not change as the band drifted",
                shots["base"][0] == shots["peak"][0],
                f"{shots['base'][0]} then {shots['peak'][0]}")
    print(f"   the band's mean brightness, recorded either way: "
          f"{shots['base'][1]:.1f} -> {shots['peak'][1]:.1f} "
          f"(delta {shots['peak'][1] - shots['base'][1]:+.1f})")


def row_10(file, motion, w, h):
    print("\nrow 10 — gentle, and it comes back to rest")
    frames, sw, sh = coarse_frames_of(file)
    if len(frames) < 3:
        video.check("10: frames were decoded", False, f"{len(frames)}")
        return
    first, last = motion["first"], motion["last"]
    scale = w / sw
    columns, rows_, numbers = [], [], []
    for index in range(max(0, first), min(last + 1, len(frames))):
        column, row = marker_in(frames[index], sw, sh)
        if column is None or row is None:
            continue
        columns.append(column)
        rows_.append(row)
        numbers.append(index)
    if len(columns) < 3:
        video.check("10: frames carried the picture", False, f"{len(columns)}")
        return
    step_x = max(abs(b - a) for a, b in zip(columns, columns[1:])) * scale
    step_y = max(abs(b - a) for a, b in zip(rows_, rows_[1:])) * scale
    # The cosine's own maximum step at the bound is pi * cap / period, mapped
    # onto the frame: about 12 px across and 7 down on a 50-frame cycle, so 16
    # (the scaled frame's own rounding included) is the ceiling.
    # The reader's own requirement (2026-10-19): 「每次移动的距离小一些（不跳）」 —
    # so the claim is a ceiling on one step, not a ceiling on the travel: 1–2 % of
    # the frame over an 8 s cycle, repainted every six frames, is under 4 px a
    # step even at the fastest point of the cosine.
    video.check("10: no step moved the picture by more than 4 px",
                max(step_x, step_y) <= 4,
                f"across {step_x:.1f}, down {step_y:.1f} frame px")
    video.check("10: the picture still moves at all",
                (max(columns) - min(columns)) * scale > 0 or
                (max(rows_) - min(rows_)) * scale > 0,
                f"across {max(columns) - min(columns)} scaled px, "
                f"down {max(rows_) - min(rows_)} scaled px")
    rest_column = 384 / scale
    rest_row = 252 / scale
    hits = [n for n, c, r in zip(numbers, columns, rows_)
            if abs(c - rest_column) <= 2 or abs(r - rest_row) <= 2]
    gaps = [hits[i + 1] - hits[i] for i in range(len(hits) - 1)]
    # SC-003 as the reader's instruction re-cut it: one cycle is 240 frames (8 s),
    # so the framing that rests recurs once in that window.
    video.check("10: the framing rests at least once every 240 frames",
                bool(hits) and (max(gaps) if gaps else 10 ** 6) <= 240,
                f"{len(hits)} resting frames, worst gap "
                f"{max(gaps) if gaps else 'n/a'}")
    still = video.screencap(os.path.join(OUT, "motion_row10_still.png"))
    print(f"   the reader's still: {still or 'none'}")


def row_13(off_file, on_file):
    print("\nrow 13 — what the effect does not change")
    off = probe_stream(off_file)
    on = probe_stream(on_file)
    print(f"   off: {off}")
    print(f"   on : {on}")
    video.check("13: the frame count is the same", off["frames"] == on["frames"],
                f"{off['frames']} vs {on['frames']}")
    video.check("13: the rate is the same", off["rate"] == on["rate"],
                f"{off['rate']} vs {on['rate']}")
    video.check("13: the duration is the same", off["duration"] == on["duration"],
                f"{off['duration']} vs {on['duration']}")
    video.check("13: the audio stream is byte-identical",
                bool(off["audio_md5"]) and off["audio_md5"] == on["audio_md5"],
                f"{off['audio_md5']} vs {on['audio_md5']}")


def probe_stream(file):
    """ffprobe's own reading of a file: frames, rate, duration, and the audio
    stream's md5."""
    import subprocess
    out = subprocess.run(
        ["ffprobe", "-v", "error", "-count_frames", "-show_streams",
         "-show_format", "-of", "json", file],
        capture_output=True, text=True)
    doc = json.loads(out.stdout or "{}")
    streams = doc.get("streams", [])
    v = next((s for s in streams if s.get("codec_type") == "video"), {})
    a = next((s for s in streams if s.get("codec_type") == "audio"), {})
    md5 = subprocess.run(
        ["ffmpeg", "-v", "error", "-i", file, "-map", "0:a", "-f", "md5", "-"],
        capture_output=True, text=True).stdout.strip()
    return {
        "frames": int(v.get("nb_read_frames") or 0),
        "rate": v.get("r_frame_rate"),
        "duration": doc.get("format", {}).get("duration"),
        "audio": a.get("codec_name"),
        "audio_md5": md5,
    }


def framemd5(file):
    """The video stream's per-frame md5 list, in order: what "the same frames"
    means when a container's own bytes carry timestamps."""
    import subprocess
    return subprocess.run(
        ["ffmpeg", "-v", "error", "-i", file, "-map", "0:v", "-f", "framemd5", "-"],
        capture_output=True, text=True).stdout.strip().splitlines()


def main():
    if len(sys.argv) < 2:
        print(__doc__)
        sys.exit(2)
    row = sys.argv[1]
    video.preflight()
    # A previous run can leave the platform's file dialog or a review on screen
    # (the row that failed mid-dialog does exactly that), and then every tap this
    # row makes lands on the wrong surface. Two backs clear any such modal.
    for _ in range(2):
        video.adb("shell", "input", "keyevent", "4")
        time.sleep(0.7)
    video.start_app() if hasattr(video, "start_app") else None
    time.sleep(1.5)
    if row not in ("9", "10", "11", "12", "13", "14", "14base"):
        print(f"row {row} has no body in this driver (15 is the structural row).")
        sys.exit(2)
    os.makedirs(OUT, exist_ok=True)
    path = fixture()
    video.push_pictures([path])
    if row == "11":
        video.push_pictures([os.path.join(OUT, "pics_023", BANDS)])
    if row in ("12", "13"):
        if not open_preset():
            sys.exit(1)
    elif not seed():
        sys.exit(1)
    if row == "14base":
        # The pre-feature build (`0ef44e7`, built in its own worktree): one off
        # render, its own per-frame md5 list on disk for row 14 to compare
        # against. The switch row is absent here, which is the point.
        print("\nrow 14base — the base commit's build, off, one render")
        out = render("14base", motion=False, switch_required=False)
        if not out:
            sys.exit(1)
        lines = framemd5(out[0])
        target = (os.environ.get("KLHU_BASE_FRAMEMD5")
                  or os.path.join(OUT, "row14_base.framemd5"))
        with open(target, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines) + "\n")
        print(f"   wrote {len(lines)} md5 lines to {target}")
        return
    if row == "14":
        # With the effect off: two renders of one content, compared frame for
        # frame; and, when a base build's list is handed in, those frames
        # against the pre-feature build's.
        print("\nrow 14 — with the effect off, the frames are the shipped frames")
        first = render("14a", motion=False)
        if not first:
            sys.exit(1)
        if not leave_review():
            video.check("14: the page came back from the first review", False)
            sys.exit(1)
        second = render("14b", motion=False)
        if not second:
            sys.exit(1)
        a_md5 = framemd5(first[0])
        b_md5 = framemd5(second[0])
        video.check("14: two off renders agree frame for frame",
                    a_md5 == b_md5, f"{len(a_md5)} vs {len(b_md5)} md5 lines")
        base = os.environ.get("KLHU_BASE_FRAMEMD5", "")
        if not base:
            print("   NOTE: the half against 0ef44e7's build was not asked for "
                  "in this run (KLHU_BASE_FRAMEMD5 unset).")
            return
        if not os.path.exists(base):
            video.check("14: the base build's md5 list was found", False, base)
            return
        with open(base, encoding="utf-8") as handle:
            base_md5 = handle.read().splitlines()
        rows_here = [line for line in a_md5 if not line.startswith("#")]
        rows_base = [line for line in base_md5
                     if line.strip() and not line.startswith("#")]
        same = rows_here == rows_base
        where_first = next((i for i, (x, y) in enumerate(zip(rows_here, rows_base))
                            if x != y), None)
        video.check("14: the frames are the base build's frames",
                    same, f"{len(rows_here)} vs {len(rows_base)} frames"
                    + ("" if same else f", first differs at frame {where_first}"))
        return
    if row == "13":
        # The same content twice: the effect off, then on — what the effect does
        # not change (FR-010, SC-006), and the ratio the cost question needs.
        # The order matters: the store opens off, and the on run's confirm is
        # what would turn it on.
        print("\nrow 13 — off, then on, on one content")
        off = render("13off", motion=False)
        if not off:
            sys.exit(1)
        print("   off wall: %.0f s" % off[4])
        if not leave_review():
            video.check("13: the page came back from the first review", False)
            sys.exit(1)
        on = render("13on", motion=True)
        if not on:
            sys.exit(1)
        ratio = on[4] / off[4] if off[4] else 0.0
        video.check("13: the on render's wall time, as a ratio of the off one",
                    ratio > 0, f"{on[4]:.0f} s / {off[4]:.0f} s = {ratio:.2f} ×")
        row_13(off[0], on[0])
        return
    if row == "12":
        print("\nrow 12 — the effect-on render's wall time (probe P1)")
        out = render("12", motion=True)
        if not out:
            sys.exit(1)
        local, ms, size, frames, wall = out
        line = re.search(r"klhu render time synth=(\d+)ms paint=(\d+)ms "
                         r"send=(\d+)ms total=(\d+)ms finish=(\d+)ms "
                         r"sentences=(\d+) pictures=(\d+) frames=(\d+)",
                         video.logcat())
        video.check("12: the app's own accounting was printed", line is not None,
                    line.group(0) if line else "no 'klhu render time' line")
        ceiling = 90885
        video.check("12: within SC-005's ceiling (1.5 × 012's 60 590 ms)",
                    wall * 1000 <= ceiling,
                    f"{wall * 1000:.0f} ms of {ceiling} ms — recorded either way")
        print(f"   frames={frames} synth/paint/send from the app's own line")
    else:
        PICTURE_FOR_ROW[row] = BANDS if row == "11" else PICTURE
        out = render(row, motion=True)
        if not out:
            sys.exit(1)
        local, ms, size, frames, wall = out
        motion = motion_line()
        size_w, size_h = 1920, 1080
        if row == "9":
            row_9(local, frames, size_w, size_h)
        elif row == "11":
            if not motion:
                video.check("11: the render printed its motion line", False)
            else:
                row_11(local, motion, size_w, size_h)
        else:
            if not motion:
                video.check("10: the render printed its motion line", False)
            else:
                row_10(local, motion, size_w, size_h)
    video.done() if hasattr(video, "done") else None


if __name__ == "__main__":
    main()
