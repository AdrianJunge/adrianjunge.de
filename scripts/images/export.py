#!/usr/bin/env python3
"""Rebuild committed public image exports; never alter authoring originals."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
import re
import shutil
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "app/assets/images"
ORIGINALS = ROOT / "content/images/originals"
MANIFEST = ROOT / "config/image_variants.json"
RASTER = {".png", ".jpg", ".jpeg", ".webp"}


def is_logo(path: Path) -> bool:
    return not {"posts", "writeups", "variants"}.intersection(path.parts) and path.name not in {
        "profile.webp", "social-card.png"
    }


def save_webp(image: Image.Image, path: Path, *, lossless: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "WEBP", quality=88, method=6, lossless=lossless, exact=True)


def export_logo(source: Path, manifest: dict) -> None:
    relative = source.relative_to(ORIGINALS)
    target = ASSETS / relative
    target.parent.mkdir(parents=True, exist_ok=True)
    with Image.open(source) as original:
        original = ImageOps.exif_transpose(original).convert("RGBA")
        fallback = original.copy()
        fallback.thumbnail((384, 384), Image.Resampling.LANCZOS)
        fallback_export = fallback.convert("RGB") if target.suffix.lower() in {".jpg", ".jpeg"} else fallback
        fallback_export.save(target, optimize=True)
        variants = []
        for bound in (96, 192, 384):
            image = original.copy()
            image.thumbnail((bound, bound), Image.Resampling.LANCZOS)
            if variants and variants[-1]["width"] == image.width:
                continue
            name = re.sub(r"[^a-zA-Z0-9_.-]+", "-", relative.stem)
            logical = Path("variants") / relative.parent / f"{name}-{image.width}.webp"
            save_webp(image, ASSETS / logical)
            variants.append({"path": logical.as_posix(), "width": image.width})
        manifest[relative.as_posix()] = {
            "src": variants[-1]["path"], "width": fallback.width,
            "height": fallback.height, "variants": variants,
        }


def export_social_card(font_dir: Path) -> None:
    # A typography-led card avoids enlarging the 128px avatar into a blurry hero.
    image = Image.new("RGB", (1200, 630), "#102139")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((44, 44, 1156, 586), radius=28, fill="#182f4f", outline="#527ba4", width=2)
    draw.rounded_rectangle((90, 110, 98, 504), radius=4, fill="#80b9fa")
    bold = str(font_dir / "DejaVuSans-Bold.ttf")
    regular = str(font_dir / "DejaVuSans.ttf")
    draw.text((140, 120), "ADRIANJUNGE.DE", font=ImageFont.truetype(regular, 25), fill="#a9c8e8")
    draw.text((135, 205), "Adrian Junge", font=ImageFont.truetype(bold, 76), fill="#f1f7ff")
    draw.text((140, 328), "Security research & software engineering", font=ImageFont.truetype(regular, 34), fill="#d0e2f5")
    draw.text((140, 453), "Articles  /  CTF writeups  /  Projects", font=ImageFont.truetype(regular, 27), fill="#a9c8e8")
    image.save(ASSETS / "landing/social-card.png", optimize=True)


def svg_dimensions(path: Path) -> tuple[int, int] | None:
    node = ET.parse(path).getroot()
    width, height = node.get("width", ""), node.get("height", "")
    if re.fullmatch(r"[\d.]+(?:px)?", width) and re.fullmatch(r"[\d.]+(?:px)?", height):
        return round(float(width.removesuffix("px"))), round(float(height.removesuffix("px")))
    viewbox = node.get("viewBox", "").replace(",", " ").split()
    return (round(float(viewbox[2])), round(float(viewbox[3]))) if len(viewbox) == 4 else None


def check() -> None:
    manifest = json.loads(MANIFEST.read_text())
    for logical, entry in manifest.items():
        assert (ASSETS / logical).is_file(), f"Missing logical asset: {logical}"
        for variant in [{"path": entry["src"], "width": entry["width"]}, *entry.get("variants", [])]:
            path = ASSETS / variant["path"]
            assert path.is_file(), f"Missing variant: {path}"
            if path.suffix == ".svg":
                width, height = svg_dimensions(path)
            else:
                with Image.open(path) as image:
                    assert image.format == Image.registered_extensions()[path.suffix], f"Incorrect extension: {path}"
                    width, height = image.size
            assert width == variant["width"], f"Incorrect width: {path}"
            if variant["path"] == entry["src"]:
                assert height == entry["height"], f"Incorrect height: {path}"
    print(f"Verified {len(manifest)} image descriptors and their published variants.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--import-current", action="store_true", help="Copy new logo originals from assets once; existing originals are never overwritten.")
    parser.add_argument("--font-dir", type=Path, default=Path("/usr/share/fonts/truetype/dejavu"))
    args = parser.parse_args()
    if args.check:
        check()
        return
    if args.import_current:
        for source in sorted(ASSETS.rglob("*")):
            if source.suffix in RASTER and is_logo(source.relative_to(ASSETS)):
                target = ORIGINALS / source.relative_to(ASSETS)
                if not target.exists():
                    target.parent.mkdir(parents=True, exist_ok=True)
                    shutil.copy2(source, target)
    manifest = {}
    for source in sorted(ORIGINALS.rglob("*")):
        if source.suffix in RASTER and is_logo(source.relative_to(ORIGINALS)):
            export_logo(source, manifest)
    export_social_card(args.font_dir)
    for source in sorted(ASSETS.rglob("*")):
        relative = source.relative_to(ASSETS).as_posix()
        if relative in manifest or relative.startswith("variants/"):
            continue
        if source.suffix in RASTER:
            with Image.open(source) as original:
                width, height = original.size
                target = source
                if source.suffix == ".png" and {"posts", "writeups"}.intersection(source.parts):
                    buffer = io.BytesIO()
                    original.save(buffer, "WEBP", lossless=True, method=6, exact=True)
                    if buffer.tell() < source.stat().st_size:
                        target = ASSETS / "variants" / Path(relative).with_suffix(".webp")
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(buffer.getvalue())
                manifest[relative] = {"src": target.relative_to(ASSETS).as_posix(), "width": width, "height": height}
        elif source.suffix == ".svg":
            dimensions = svg_dimensions(source)
            if dimensions:
                manifest[relative] = {"src": relative, "width": dimensions[0], "height": dimensions[1]}
    MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    check()


if __name__ == "__main__":
    main()
