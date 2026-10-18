"""Builds installer/icon.ico (the setup wizard, Start Menu and desktop shortcut
icon; the portable exe keeps Godot's default icon for now) from icon.svg.

Run:  python3 tools/make_icon.py   (from the project root). Requires Pillow.
icon.svg is pixel art drawn with plain <rect> elements on a 32x32 grid, so
this script paints those rects directly and scales up with nearest-neighbour,
keeping the pixels crisp at every Windows icon size. Re-run it whenever
icon.svg changes.
"""
import os
import re
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw

ROOT = os.path.join(os.path.dirname(__file__), "..")
SRC = os.path.join(ROOT, "icon.svg")
OUT = os.path.join(ROOT, "installer", "icon.ico")
GRID = 32
SIZES = [16, 24, 32, 48, 64, 128, 256]


def main() -> None:
    tree = ET.parse(SRC)
    img = Image.new("RGBA", (GRID, GRID), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    for el in tree.iter():
        if not el.tag.endswith("rect"):
            continue
        x = int(float(el.get("x", 0)))
        y = int(float(el.get("y", 0)))
        w = int(float(el.get("width")))
        h = int(float(el.get("height")))
        fill = el.get("fill", "#000000")
        if not re.fullmatch(r"#[0-9a-fA-F]{6}", fill):
            raise SystemExit("unsupported fill %r (use #rrggbb)" % fill)
        draw.rectangle([x, y, x + w - 1, y + h - 1], fill=fill)
    # one nearest-neighbour image per size, so Pillow doesn't smooth any of them
    frames = [img.resize((s, s), Image.NEAREST) for s in SIZES]
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    frames[-1].save(OUT, sizes=[(s, s) for s in SIZES], append_images=frames[:-1])
    print("wrote", os.path.normpath(OUT))


if __name__ == "__main__":
    main()
