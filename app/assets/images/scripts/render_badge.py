#!/usr/bin/env python3
"""Render circular image badges with a black rim.

Requires Pillow:
  python -m pip install Pillow
"""

from __future__ import annotations

import argparse
from collections import deque
from pathlib import Path

from PIL import Image, ImageDraw, ImageFilter, ImageOps


def parse_color(value: str | None) -> tuple[int, int, int, int] | None:
    if value is None or value.lower() == "none":
        return None

    named = {
        "white": (255, 255, 255, 255),
        "black": (0, 0, 0, 255),
    }
    if value.lower() in named:
        return named[value.lower()]

    raw = value.removeprefix("#")
    if len(raw) not in (6, 8):
        raise argparse.ArgumentTypeError("colors must be named, #RRGGBB, #RRGGBBAA, or none")

    channels = [int(raw[index : index + 2], 16) for index in range(0, len(raw), 2)]
    if len(channels) == 3:
        channels.append(255)
    return tuple(channels)


def parse_box(value: str | None) -> tuple[int, int, int, int] | None:
    if not value:
        return None
    parts = [int(part.strip()) for part in value.split(",")]
    if len(parts) != 4:
        raise argparse.ArgumentTypeError("crop boxes must be left,top,right,bottom")
    return tuple(parts)


def draw_shell(
    size: int,
    outer_margin: int,
    inner_margin: int,
    inner_fill: tuple[int, int, int, int] | None,
) -> Image.Image:
    canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))

    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.ellipse(
        (
            outer_margin + 8,
            outer_margin + 14,
            size - outer_margin + 8,
            size - outer_margin + 14,
        ),
        fill=(0, 0, 0, 110),
    )
    canvas.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10)))

    draw = ImageDraw.Draw(canvas)
    outer = (outer_margin, outer_margin, size - outer_margin, size - outer_margin)
    draw.ellipse(outer, fill=(2, 7, 15, 255), outline=(39, 55, 80, 255), width=3)

    if inner_fill is not None:
        inner = (inner_margin, inner_margin, size - inner_margin, size - inner_margin)
        draw.ellipse(inner, fill=inner_fill, outline=(176, 190, 211, 145), width=2)

    draw.arc(
        (outer_margin + 18, outer_margin + 13, size - outer_margin - 18, size - outer_margin - 24),
        202,
        338,
        fill=(255, 255, 255, 80),
        width=2,
    )
    draw.arc(
        (outer_margin + 18, outer_margin + 21, size - outer_margin - 17, size - outer_margin - 13),
        22,
        158,
        fill=(0, 0, 0, 115),
        width=4,
    )
    draw.arc(
        (outer_margin + 39, outer_margin + 32, size - outer_margin - 52, size - outer_margin - 50),
        198,
        292,
        fill=(255, 255, 255, 48),
        width=2,
    )

    return canvas


def is_light_background_pixel(
    pixel: tuple[int, int, int, int],
    threshold: int,
    slack: int,
) -> bool:
    red, green, blue, alpha = pixel
    return alpha > 0 and min(red, green, blue) >= threshold and max(red, green, blue) - min(red, green, blue) <= slack


def remove_light_background_threshold(
    image: Image.Image,
    threshold: int,
    slack: int,
) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    for y in range(result.height):
        for x in range(result.width):
            if is_light_background_pixel(pixels[x, y], threshold, slack):
                red, green, blue, _alpha = pixels[x, y]
                pixels[x, y] = (red, green, blue, 0)
    return result


def remove_light_background_from_edges(
    image: Image.Image,
    threshold: int,
    slack: int,
) -> Image.Image:
    result = image.convert("RGBA")
    pixels = result.load()
    width, height = result.size
    visited: set[tuple[int, int]] = set()
    queue: deque[tuple[int, int]] = deque()

    for x in range(width):
        queue.append((x, 0))
        queue.append((x, height - 1))
    for y in range(height):
        queue.append((0, y))
        queue.append((width - 1, y))

    while queue:
        x, y = queue.popleft()
        if (x, y) in visited:
            continue
        visited.add((x, y))

        if not is_light_background_pixel(pixels[x, y], threshold, slack):
            continue

        red, green, blue, _alpha = pixels[x, y]
        pixels[x, y] = (red, green, blue, 0)

        if x > 0:
            queue.append((x - 1, y))
        if x < width - 1:
            queue.append((x + 1, y))
        if y > 0:
            queue.append((x, y - 1))
        if y < height - 1:
            queue.append((x, y + 1))

    return result


def alpha_composite_masked(base: Image.Image, content: Image.Image, mask: Image.Image, position: tuple[int, int]) -> None:
    layer = Image.new("RGBA", content.size, (0, 0, 0, 0))
    layer.alpha_composite(content)
    layer.putalpha(Image.composite(layer.getchannel("A"), Image.new("L", content.size, 0), mask))
    base.alpha_composite(layer, position)


def paste_full_circle(
    canvas: Image.Image,
    source: Image.Image,
    inner_margin: int,
    crop_box: tuple[int, int, int, int] | None,
    background: str,
    threshold: int,
    slack: int,
) -> None:
    size = canvas.size[0]
    inner_size = size - 2 * inner_margin
    image = source.convert("RGBA")
    if crop_box:
        image = image.crop(crop_box)
    if background == "threshold":
        image = remove_light_background_threshold(image, threshold, slack)
    elif background == "edge":
        image = remove_light_background_from_edges(image, threshold, slack)

    content = ImageOps.fit(image, (inner_size, inner_size), Image.Resampling.LANCZOS, centering=(0.5, 0.5))
    mask = Image.new("L", (inner_size, inner_size), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, inner_size - 1, inner_size - 1), fill=255)
    alpha_composite_masked(canvas, content, mask, (inner_margin, inner_margin))

    draw = ImageDraw.Draw(canvas)
    draw.ellipse((inner_margin, inner_margin, size - inner_margin, size - inner_margin), outline=(0, 0, 0, 120), width=2)


def prepare_logo(
    source: Image.Image,
    background: str,
    threshold: int,
    slack: int,
    crop_box: tuple[int, int, int, int] | None,
) -> Image.Image:
    image = source.convert("RGBA")
    if crop_box:
        image = image.crop(crop_box)

    if background == "threshold":
        image = remove_light_background_threshold(image, threshold, slack)
    elif background == "edge":
        image = remove_light_background_from_edges(image, threshold, slack)

    bbox = image.getbbox()
    if bbox:
        image = image.crop(bbox)
    return image


def paste_logo(
    canvas: Image.Image,
    source: Image.Image,
    inner_margin: int,
    logo_scale: float,
    background: str,
    threshold: int,
    slack: int,
    crop_box: tuple[int, int, int, int] | None,
) -> None:
    size = canvas.size[0]
    max_side = int((size - 2 * inner_margin) * logo_scale)
    logo = prepare_logo(source, background, threshold, slack, crop_box)
    logo.thumbnail((max_side, max_side), Image.Resampling.LANCZOS)
    canvas.alpha_composite(logo, ((size - logo.width) // 2, (size - logo.height) // 2))


def save_image(image: Image.Image, output: Path, matte: tuple[int, int, int, int]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    if output.suffix.lower() in {".jpg", ".jpeg"}:
        background = Image.new("RGBA", image.size, matte)
        background.alpha_composite(image)
        background.convert("RGB").save(output, quality=95, optimize=True, progressive=True)
    else:
        image.save(output, optimize=True)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Render a circular badge with a black rim.")
    parser.add_argument("input", type=Path)
    parser.add_argument("output", type=Path)
    parser.add_argument("--mode", choices=("logo", "full"), default="logo")
    parser.add_argument("--size", type=int, default=512)
    parser.add_argument("--outer-margin", type=int, default=10)
    parser.add_argument("--inner-margin", type=int, default=58)
    parser.add_argument("--inner-fill", type=parse_color, default=parse_color("white"))
    parser.add_argument("--logo-scale", type=float, default=0.74)
    parser.add_argument("--background", choices=("auto", "none", "threshold", "edge"), default="auto")
    parser.add_argument("--light-threshold", type=int, default=238)
    parser.add_argument("--light-slack", type=int, default=28)
    parser.add_argument("--crop", type=parse_box)
    parser.add_argument("--matte", type=parse_color, default=parse_color("#18243a"))
    return parser


def main() -> None:
    args = build_parser().parse_args()
    if args.background == "auto":
        args.background = "none" if args.mode == "full" else "threshold"
    if args.mode == "full" and args.inner_fill is not None:
        # Full-image badges use the artwork itself as the inner circle.
        args.inner_fill = None

    source = Image.open(args.input)
    badge = draw_shell(args.size, args.outer_margin, args.inner_margin, args.inner_fill)

    if args.mode == "full":
        paste_full_circle(
            badge,
            source,
            args.inner_margin,
            args.crop,
            args.background,
            args.light_threshold,
            args.light_slack,
        )
    else:
        paste_logo(
            badge,
            source,
            args.inner_margin,
            args.logo_scale,
            args.background,
            args.light_threshold,
            args.light_slack,
            args.crop,
        )

    save_image(badge, args.output, args.matte)


if __name__ == "__main__":
    main()
