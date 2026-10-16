#!/usr/bin/env python3
"""Generate tinted PLACEHOLDER launcher icons per flavor (MC-008 approved design pending).

    python3 tool/make_icons.py            # writes everything below
    python3 tool/make_icons.py --check    # exit 1 if files are missing (CI-friendly, writes nothing)

Writes
  android/app/src/{dev,staging,prod}/res/mipmap-{mdpi,hdpi,xhdpi,xxhdpi,xxxhdpi}/ic_launcher.png
  ios/Runner/Assets.xcassets/AppIcon-{dev,staging,prod}.appiconset/*.png + Contents.json

The design is deliberately generic (two linked rings on a flavor tint) so nobody mistakes it for the
brand mark. iOS icons are opaque RGB (the App Store rejects alpha). Uses Pillow when installed, else a
pure-python rasteriser + PNG writer (stdlib only); both draw the same geometry.
"""

import argparse
import json
import math
import struct
import sys
import zlib
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TINTS = {  # flavor -> RGB background
    "dev": (0xE8, 0x73, 0x0C),  # orange
    "staging": (0x6F, 0x42, 0xC1),  # purple
    "prod": (0x8E, 0x2A, 0x5B),  # plum (placeholder brand colour)
}
ANDROID = {"mdpi": 48, "hdpi": 72, "xhdpi": 96, "xxhdpi": 144, "xxxhdpi": 192}
# Geometry in unit coordinates.
RINGS = [((0.40, 0.5), 0.20), ((0.60, 0.5), 0.20)]
STROKE = 0.055
WHITE = (255, 255, 255)

try:  # pragma: no cover - depends on the environment
    from PIL import Image, ImageChops, ImageDraw

    HAVE_PIL = True
except ImportError:  # pragma: no cover
    HAVE_PIL = False


def render_pil(size: int, tint: tuple[int, int, int]) -> bytes:
    ss = 4
    big = size * ss
    mask = Image.new("L", (big, big), 0)
    for (cx, cy), r in RINGS:  # union of the two annuli
        ring = Image.new("L", (big, big), 0)
        d = ImageDraw.Draw(ring)
        x, y = cx * big, cy * big
        outer, inner = (r + STROKE / 2) * big, (r - STROKE / 2) * big
        d.ellipse([x - outer, y - outer, x + outer, y + outer], fill=255)
        d.ellipse([x - inner, y - inner, x + inner, y + inner], fill=0)
        mask = ImageChops.lighter(mask, ring)
    img = Image.composite(Image.new("RGB", (big, big), WHITE), Image.new("RGB", (big, big), tint), mask)
    return img.resize((size, size), Image.LANCZOS).tobytes()


def _coverage(u: float, v: float) -> float:
    """1.0 where a ring is drawn at unit point (u, v)."""
    for (cx, cy), r in RINGS:
        if abs(math.hypot(u - cx, v - cy) - r) <= STROKE / 2:
            return 1.0
    return 0.0


def render_py(size: int, tint: tuple[int, int, int]) -> bytes:
    out = bytearray()
    sub = (0.25, 0.75)
    for y in range(size):
        for x in range(size):
            c = sum(_coverage((x + a) / size, (y + b) / size) for a in sub for b in sub) / 4
            out += bytes(round(tint[i] + (WHITE[i] - tint[i]) * c) for i in range(3))
    return bytes(out)


def png_bytes(size: int, rgb: bytes) -> bytes:
    def chunk(tag: bytes, data: bytes) -> bytes:
        body = tag + data
        return struct.pack(">I", len(data)) + body + struct.pack(">I", zlib.crc32(body) & 0xFFFFFFFF)

    stride = size * 3
    raw = b"".join(b"\x00" + rgb[y * stride : (y + 1) * stride] for y in range(size))
    return (
        b"\x89PNG\r\n\x1a\n"
        + chunk(b"IHDR", struct.pack(">IIBBBBB", size, size, 8, 2, 0, 0, 0))
        + chunk(b"IDAT", zlib.compress(raw, 9))
        + chunk(b"IEND", b"")
    )


def make(size: int, tint: tuple[int, int, int]) -> bytes:
    rgb = render_pil(size, tint) if HAVE_PIL and "--no-pil" not in sys.argv else render_py(size, tint)
    return png_bytes(size, rgb)


def ios_sizes(contents: dict) -> dict[str, int]:
    """filename -> pixel size from the stock AppIcon Contents.json."""
    out = {}
    for im in contents["images"]:
        pt = float(im["size"].split("x")[0])
        scale = int(im["scale"].rstrip("x"))
        out[im["filename"]] = round(pt * scale)
    return out


def targets() -> list[tuple[Path, int, str]]:
    stock = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    contents = json.loads(stock.read_text())
    items = []
    for flavor in TINTS:
        for density, px in ANDROID.items():
            items.append((ROOT / f"android/app/src/{flavor}/res/mipmap-{density}/ic_launcher.png", px, flavor))
        set_dir = ROOT / f"ios/Runner/Assets.xcassets/AppIcon-{flavor}.appiconset"
        for name, px in ios_sizes(contents).items():
            items.append((set_dir / name, px, flavor))
    return items


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("--check", action="store_true")
    ap.add_argument("--no-pil", action="store_true", help="force the pure-python path")
    args = ap.parse_args()
    stock = ROOT / "ios/Runner/Assets.xcassets/AppIcon.appiconset/Contents.json"
    items = targets()
    if args.check:
        missing = [str(p) for p, _, _ in items if not p.exists()]
        for flavor in TINTS:
            c = ROOT / f"ios/Runner/Assets.xcassets/AppIcon-{flavor}.appiconset/Contents.json"
            if not c.exists():
                missing.append(str(c))
        print("\n".join(missing) or "all icons present")
        return 1 if missing else 0
    cache: dict[tuple[int, str], bytes] = {}
    for path, px, flavor in items:
        path.parent.mkdir(parents=True, exist_ok=True)
        key = (px, flavor)
        if key not in cache:
            cache[key] = make(px, TINTS[flavor])
        path.write_bytes(cache[key])
    for flavor in TINTS:
        d = ROOT / f"ios/Runner/Assets.xcassets/AppIcon-{flavor}.appiconset"
        (d / "Contents.json").write_text(stock.read_text())
    print(f"wrote {len(items)} icons with {'Pillow' if HAVE_PIL and not args.no_pil else 'pure python'}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
