#!/usr/bin/env python3
"""T007 (pass 5): the two OS surfaces that render the icon at a size worth
comparing — the app-info header (centred template match) and the launcher's app
drawer, where uiautomator does export the app label and therefore the cell.
"""
import os
import re
import subprocess
import time

from PIL import Image, ImageChops

ADB = ["adb", "-s", os.environ.get("ADB_SERIAL", "emulator-5554")]
OUT = os.environ.get("KLHU_OUT", "/tmp")
PKG = "com.example.klhu"
LABEL = "KalaHoo Reading"


def sh(*a, binary=False):
    r = subprocess.run(ADB + list(a), capture_output=True)
    return r.stdout if binary else r.stdout.decode("utf-8", "replace")


def shot(path):
    with open(path, "wb") as f:
        f.write(sh("exec-out", "screencap", "-p", binary=True))
    return Image.open(path).convert("RGB")


def dump():
    sh("shell", "rm", "-f", "/sdcard/ui.xml")
    sh("shell", "uiautomator", "dump", "/sdcard/ui.xml")
    xml = sh("shell", "cat", "/sdcard/ui.xml")
    out = []
    for m in re.finditer(r"<node[^>]*>", xml):
        tag = m.group(0)

        def a(n):
            mm = re.search(rf'{n}="([^"]*)"', tag)
            return mm.group(1) if mm else ""

        b = a("bounds")
        if b:
            l, t, r, bo = map(int, re.findall(r"-?\d+", b))
            out.append(dict(text=a("text"), desc=a("content-desc"), box=(l, t, r, bo)))
    return out


def expected(art, size=256, inset=0.16):
    canvas = Image.new("RGB", (size, size), (255, 255, 255))
    side = int(round(size * (1 - 2 * inset)))
    canvas.paste(art.resize((side, side), Image.LANCZOS),
                 ((size - side) // 2, (size - side) // 2))
    return canvas


def mad(img, box, cand):
    crop = img.crop(box).resize((256, 256), Image.LANCZOS)
    m = int(256 * 0.2)
    c, e = crop.crop((m, m, 256 - m, 256 - m)), cand.crop((m, m, 256 - m, 256 - m))
    return sum(ImageChops.difference(c, e).convert("L").getdata()) / (c.width * c.height)


def main():
    ours = expected(Image.open("images/kalahoo.jpeg").convert("RGB"))
    subprocess.run(["git", "show", "HEAD:android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png"],
                   stdout=open(f"{OUT}/klhu_009_default.png", "wb"), check=True)
    default = expected(Image.open(f"{OUT}/klhu_009_default.png").convert("RGB"))

    # ---- app-info header ----------------------------------------------------
    sh("shell", "am", "start", "-a", "android.settings.APPLICATION_DETAILS_SETTINGS",
       "-d", f"package:{PKG}")
    time.sleep(3)
    settings = shot(f"{OUT}/klhu_009_settings.png")
    hdr = [n for n in dump() if n["text"] == LABEL]
    print(f"1) app-info header: label node {hdr[0]['box'] if hdr else 'NOT FOUND'}")
    if hdr:
        l, t, r, b = hdr[0]["box"]
        cx = (l + r) // 2
        rows = []
        for size in range(260, 481, 20):
            for cy in range(470, 840, 10):
                box = (cx - size // 2, cy, cx + size // 2, cy + size)
                rows.append((mad(settings, box, ours), mad(settings, box, default), box))
        rows.sort()
        o, d, box = rows[0]
        settings.crop(box).save(f"{OUT}/klhu_009_settings_cell.png")
        print(f"   best centred box {box}: MAD ours={o:.1f} default={d:.1f} -> "
              f"{'OURS' if o < d else 'THE DEFAULT'} (ratio {o/d:.2f})")
        print(f"   runner-up boxes: {[(round(a,1), round(b,1), bx) for a,b,bx in rows[1:3]]}")

    # ---- launcher app drawer ------------------------------------------------
    sh("shell", "input", "keyevent", "3")
    time.sleep(3)
    sh("shell", "input", "swipe", "540", "1900", "540", "700", "300")
    time.sleep(4)
    drawer = shot(f"{OUT}/klhu_009_drawer.png")
    ns = dump()
    hit = [n for n in ns if n["text"] == LABEL or n["desc"].startswith(LABEL)]
    print(f"\n2) app drawer: {len(ns)} nodes; matches for {LABEL!r}: "
          f"{[(n['text'], n['desc'], n['box']) for n in hit]}")
    if hit:
        l, t, r, b = hit[0]["box"]
        w, h = r - l, b - t
        # the drawer cell: icon square above the label, roughly cell-wide
        rows = []
        for size in range(max(120, h * 2), h * 4 + 1, 8):
            for dy in range(10, 90, 8):
                box = (l - (size - w) // 2, t - size - dy, l - (size - w) // 2 + size, t - dy)
                rows.append((mad(drawer, box, ours), mad(drawer, box, default), box))
        rows.sort()
        o, d, box = rows[0]
        drawer.crop(box).save(f"{OUT}/klhu_009_drawer_cell.png")
        print(f"   best box {box}: MAD ours={o:.1f} default={d:.1f} -> "
              f"{'OURS' if o < d else 'THE DEFAULT'} (ratio {o/d:.2f})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
