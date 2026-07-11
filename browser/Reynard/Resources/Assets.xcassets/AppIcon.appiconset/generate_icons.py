#!/usr/bin/env python3
"""Install the approved BaklaFox v5 logo as every iOS app-icon appearance.

The approved PNG has transparent rounded corners. iOS supplies the final icon
mask and requires opaque artwork, so the transparency is composited over a
green sampled from the artwork's own outer edge. Pixels that were already
opaque are unchanged.
"""

from pathlib import Path
from statistics import median
from PIL import Image

ICON_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = ICON_DIR.parents[4]
SOURCE = PROJECT_ROOT / "assets/logos/BaklaFox-green-fox-icon-v5.png"
OUTPUTS = ("icon.png", "icon-dark.png", "icon-tint.png")
SIZE = (1024, 1024)


def sampled_edge_green(image: Image.Image) -> tuple[int, int, int]:
    px = image.load()
    samples: list[tuple[int, int, int]] = []
    w, h = image.size
    band = 48
    for y in range(h):
        for x in range(w):
            if x >= band and x < w - band and y >= band and y < h - band:
                continue
            r, g, b, a = px[x, y]
            # Prefer opaque green edge pixels and exclude the white fox.
            if a >= 250 and g > r + 20 and g > b + 10:
                samples.append((r, g, b))
    if not samples:
        return (76, 174, 98)
    return tuple(int(median(channel)) for channel in zip(*samples))


def make_opaque(source: Path) -> Image.Image:
    image = Image.open(source).convert("RGBA")
    if image.size != SIZE:
        image = image.resize(SIZE, Image.Resampling.LANCZOS)
    background = Image.new("RGBA", SIZE, (*sampled_edge_green(image), 255))
    opaque = Image.alpha_composite(background, image).convert("RGB")
    return opaque


def main() -> None:
    if not SOURCE.is_file():
        raise FileNotFoundError(SOURCE)
    icon = make_opaque(SOURCE)
    for filename in OUTPUTS:
        output = ICON_DIR / filename
        icon.save(output, "PNG", optimize=True)
        with Image.open(output) as check:
            if check.size != SIZE or check.mode != "RGB":
                raise RuntimeError(f"invalid generated icon: {output}")
        print(f"{filename}: {output.stat().st_size} bytes")


if __name__ == "__main__":
    main()
