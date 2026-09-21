"""Regenerate Android + iOS launcher icons from images/kalahu.jpeg.

Writes the missing custom-icon artifact (spec 004, SC-002 / T014):
  - Android mipmap ic_launcher.png at every density
  - iOS AppIcon.appiconset PNGs per Contents.json + 1024 marketing
Center-crop to square, then resize (LANCZOS). Idempotent.
"""
import json
import sys
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "images" / "kalahu.jpeg"


def centered_square(img: Image.Image) -> Image.Image:
    w, h = img.size
    s = min(w, h)
    left = (w - s) // 2
    top = (h - s) // 2
    return img.crop((left, top, left + s, top + s))


def resized_square(img: Image.Image, size: int) -> Image.Image:
    base = centered_square(img.convert("RGBA"))
    return base.resize((size, size), Image.Resampling.LANCZOS)


def write_png(img: Image.Image, path: Path) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    # mipmap launcher icons are RGB (opaque); keep them without an alpha layer.
    if path.name.startswith("ic_launcher"):
        img = img.convert("RGB")
    img.save(path)
    print(f"  {path.relative_to(ROOT)}  ({path.stat().st_size} bytes)")


def main() -> int:
    if not SRC.exists():
        print(f"ERROR: source icon not found: {SRC}", file=sys.stderr)
        return 1
    src = Image.open(SRC)
    print(f"Source {SRC.name}: {src.size[0]}x{src.size[1]}")

    # Android mipmap densities (Flutter default launcher names).
    android = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    print("Android mipmaps:")
    for folder, size in android.items():
        write_png(resized_square(src, size), ROOT / "android/app/src/main/res" / folder / "ic_launcher.png")

    # iOS: emit every filename named in Contents.json at its pixel size.
    appicon = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset"
    contents = json.loads((appicon / "Contents.json").read_text())
    print("iOS AppIcon:")
    seen = set()
    for entry in contents["images"]:
        fname = entry["filename"]
        if fname in seen:
            continue
        seen.add(fname)
        # pixel size: parse "Icon-App-WxH@Nx.png" (W/H may be fractional, e.g. 83.5).
        token = fname[len("Icon-App-"):]
        dimensions = token.split("@")[0]
        width = int(round(float(dimensions.split("x")[0])))
        write_png(resized_square(src, width), appicon / fname)

    print("Done.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
