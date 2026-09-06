#!/usr/bin/env python3
"""Create a quick contact sheet for comparing generated image assets.

Requires Pillow:
  python -m pip install -r scripts/images/requirements.txt
"""

from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image, ImageDraw


def parse_color(value: str) -> tuple[int, int, int, int]:
    raw = value.removeprefix("#")
    if len(raw) != 6:
        raise argparse.ArgumentTypeError("colors must be #RRGGBB")
    red, green, blue = [int(raw[index : index + 2], 16) for index in range(0, 6, 2)]
    return red, green, blue, 255


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Create a contact sheet from image files.")
    parser.add_argument("output", type=Path)
    parser.add_argument("images", type=Path, nargs="+")
    parser.add_argument("--thumb-size", type=int, default=220)
    parser.add_argument("--label-height", type=int, default=36)
    parser.add_argument("--background", type=parse_color, default=parse_color("#141e30"))
    return parser


def main() -> None:
    args = build_parser().parse_args()
    width = args.thumb_size * len(args.images)
    height = args.thumb_size + args.label_height
    sheet = Image.new("RGBA", (width, height), args.background)
    draw = ImageDraw.Draw(sheet)

    for index, path in enumerate(args.images):
        image = Image.open(path).convert("RGBA")
        image.thumbnail((args.thumb_size - 20, args.thumb_size - 20), Image.Resampling.LANCZOS)
        x = index * args.thumb_size + (args.thumb_size - image.width) // 2
        y = 10 + (args.thumb_size - 20 - image.height) // 2
        sheet.alpha_composite(image, (x, y))
        draw.text((index * args.thumb_size + 8, args.thumb_size + 8), path.name, fill=(235, 245, 255, 255))

    args.output.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(args.output, optimize=True)


if __name__ == "__main__":
    main()
