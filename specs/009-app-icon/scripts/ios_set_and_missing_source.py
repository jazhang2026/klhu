#!/usr/bin/env python3
"""T008 + T009.

T008: the iOS asset set is generated on Linux but cannot be validated without
macOS — so verify it structurally and keep the output as the evidence.
T009: FR-006 both ways — with the source image moved away, a build must still
succeed (nothing in the build reads it) and the generator must fail loudly
(non-zero exit) without touching the committed assets.
"""
import hashlib
import json
import os
import re
import pathlib
import shutil
import subprocess
import sys

from PIL import Image

REPO = pathlib.Path(os.environ.get("KLHU_REPO", ".")).resolve()
os.chdir(REPO)
IOS = REPO / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
ANDROID = REPO / "android/app/src/main/res"
SRC = REPO / "images/kalahoo.jpeg"
ENV = dict(os.environ, PATH=os.path.expanduser("~/development/flutter/bin") + ":" + os.environ["PATH"])


def generated_set():
    """Every file this feature generates, hashed."""
    files = sorted(list(ANDROID.glob("mipmap-*/ic_launcher.png")) +
                   list(ANDROID.glob("drawable-*/ic_launcher_foreground.png")) +
                   list(ANDROID.glob("mipmap-anydpi-v26/*.xml")) +
                   list(ANDROID.glob("values/colors.xml")) +
                   list(IOS.glob("*.png")) + [IOS / "Contents.json"])
    return {str(f.relative_to(REPO)): hashlib.sha256(f.read_bytes()).hexdigest() for f in files}


def t008():
    print("T008 — iOS asset set, structurally")
    entries = json.loads((IOS / "Contents.json").read_text())["images"]
    bad = []
    checked = 0
    for e in entries:
        name = e.get("filename")
        if not name:
            continue
        path = IOS / name
        side = float(e["size"].split("x")[0])
        scale = int(e["scale"].rstrip("x"))
        want = round(side * scale)
        if not path.exists():
            bad.append(f"{name}: MISSING")
            continue
        im = Image.open(path)
        band = im.getbands()
        if im.size != (want, want):
            bad.append(f"{name}: {im.size} != {want}x{want}")
        if "A" in band:
            bad.append(f"{name}: alpha channel {band}")
        checked += 1
    print(f"  catalogue entries with a filename: {sum(1 for e in entries if e.get('filename'))}"
          f" | files checked: {checked} | violations: {len(bad)}")
    for b in bad:
        print("   -", b)
    print("  PNGs are RGB (no alpha):",
          sorted({Image.open(p).mode for p in IOS.glob("*.png")}))
    print("  sizes:", {p.name: Image.open(p).size[0] for p in sorted(IOS.glob("*.png"))})
    print("  VERDICT:", "PASS (structural)" if not bad else "FAIL")
    print("  NOTE: no macOS/Xcode on this host -> the iOS device/store half of SC-002 stays")
    print("        UNVERIFIED WITH REASON; this row is structural evidence only.\n")
    return not bad


def t009():
    print("T009 — FR-006: a missing source cannot break a build")
    before = generated_set()
    stash = pathlib.Path("/home/weihongzhang/.hermes/cache/scratch/kalahoo_stashed.jpeg")
    shutil.move(SRC, stash)
    print("  source moved away:", not SRC.exists())
    try:
        b = subprocess.run(["flutter", "build", "apk", "--debug"], env=ENV,
                           capture_output=True, text=True, cwd=REPO)
        build_ok = b.returncode == 0 and "app-debug.apk" in b.stdout
        print(f"  flutter build apk --debug -> exit {b.returncode} "
              f"({'SUCCEEDED' if build_ok else 'FAILED'})")
        g = subprocess.run(["dart", "run", "flutter_launcher_icons"], env=ENV,
                           capture_output=True, text=True, cwd=REPO)
        tail = [l for l in (g.stdout + g.stderr).splitlines() if l.strip()][-3:]
        print(f"  dart run flutter_launcher_icons -> exit {g.returncode} "
              f"({'fails loudly' if g.returncode != 0 else 'DID NOT FAIL'})")
        for l in tail:
            print("    |", l[:110])
    finally:
        shutil.move(stash, SRC)
    after = generated_set()
    print("  source restored:", SRC.exists())
    changed = [k for k in before if before.get(k) != after.get(k)]
    print("  committed assets touched by the failed run:", changed or "none")
    return build_ok and g.returncode != 0 and not changed


if __name__ == "__main__":
    ok8, ok9 = t008(), t009()
    print(f"\nT008 {'PASS' if ok8 else 'FAIL'} | T009 {'PASS' if ok9 else 'FAIL'}")
    sys.exit(0 if ok8 and ok9 else 1)
