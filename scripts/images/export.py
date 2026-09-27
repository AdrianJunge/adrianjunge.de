#!/usr/bin/env python3
"""Rebuild committed public image exports; never alter authoring originals."""

from __future__ import annotations

import argparse
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import xml.etree.ElementTree as ET

from PIL import Image, ImageDraw, ImageFont, ImageOps

ROOT = Path(__file__).resolve().parents[2]
ASSETS = ROOT / "app/assets/images"
ORIGINALS = ROOT / "content/images/originals"
MANIFEST = ROOT / "config/image_variants.json"
RASTER = {".png", ".jpg", ".jpeg", ".webp"}
SVGO = ROOT / "node_modules/.bin/svgo"
FONT_DIR = Path("/usr/share/fonts/truetype/dejavu")


def is_logo(path: Path) -> bool:
    return not {"posts", "writeups", "variants"}.intersection(path.parts) and path.name not in {
        "profile.webp", "social-card.png"
    }


def save_webp(image: Image.Image, path: Path, *, lossless: bool = False) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    image.save(path, "WEBP", quality=88, method=6, lossless=lossless, exact=True)


def export_logo(source: Path, manifest: dict, assets: Path | None = None) -> None:
    assets = assets or ASSETS
    relative = source.relative_to(ORIGINALS)
    target = assets / relative
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
            save_webp(image, assets / logical)
            variants.append({"path": logical.as_posix(), "width": image.width})
        manifest[relative.as_posix()] = {
            "src": variants[-1]["path"], "width": fallback.width,
            "height": fallback.height, "variants": variants,
        }


def export_social_card(font_dir: Path, assets: Path | None = None) -> None:
    assets = assets or ASSETS
    # A typography-led card avoids enlarging the 128px avatar into a blurry hero.
    image = Image.new("RGB", (1200, 630), "#102139")
    draw = ImageDraw.Draw(image)
    draw.rounded_rectangle((44, 44, 1156, 586), radius=28, fill="#182f4f", outline="#527ba4", width=2)
    draw.rounded_rectangle((90, 110, 98, 504), radius=4, fill="#80b9fa")
    bold = str(font_dir / "DejaVuSans-Bold.ttf")
    regular = str(font_dir / "DejaVuSans.ttf")
    draw.text((140, 120), "ADRIANJUNGE.DE", font=ImageFont.truetype(regular, 25), fill="#a9c8e8")
    draw.text((135, 205), "Adrian Junge (vurlo)", font=ImageFont.truetype(bold, 76), fill="#f1f7ff")
    draw.text((140, 328), "Security research & bug bounty hunting", font=ImageFont.truetype(regular, 34), fill="#d0e2f5")
    draw.text((140, 453), "Posts  /  CTF writeups  /  CVEs", font=ImageFont.truetype(regular, 27), fill="#a9c8e8")
    target = assets / "landing/social-card.png"
    target.parent.mkdir(parents=True, exist_ok=True)
    image.save(target, optimize=True)


def svg_dimensions(path: Path) -> tuple[int, int] | None:
    node = ET.parse(path).getroot()
    width, height = node.get("width", ""), node.get("height", "")
    if re.fullmatch(r"[\d.]+(?:px)?", width) and re.fullmatch(r"[\d.]+(?:px)?", height):
        return round(float(width.removesuffix("px"))), round(float(height.removesuffix("px")))
    viewbox = node.get("viewBox", "").replace(",", " ").split()
    return (round(float(viewbox[2])), round(float(viewbox[3]))) if len(viewbox) == 4 else None


def rebuild(assets: Path, font_dir: Path) -> dict:
    """Generate into a fresh directory, excluding previously generated variants."""
    for source in sorted(ASSETS.rglob("*")):
        relative = source.relative_to(ASSETS)
        if source.is_file() and relative.parts[0] != "variants":
            target = assets / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
    manifest = {}
    for source in sorted(ORIGINALS.rglob("*")):
        relative = source.relative_to(ORIGINALS)
        if source.suffix.lower() in RASTER and is_logo(relative):
            export_logo(source, manifest, assets)
        elif source.suffix.lower() == ".svg":
            if not SVGO.is_file():
                raise ValueError("Missing locked SVG optimizer; run npm ci first.")
            target = assets / relative
            target.parent.mkdir(parents=True, exist_ok=True)
            subprocess.run([str(SVGO), str(source), "--output", str(target), "--quiet"], check=True)
    export_social_card(font_dir, assets)
    for source in sorted(assets.rglob("*")):
        relative = source.relative_to(assets).as_posix()
        if relative in manifest or relative.startswith("variants/"):
            continue
        if source.suffix.lower() in RASTER:
            with Image.open(source) as original:
                if original.format != Image.registered_extensions()[source.suffix.lower()]:
                    raise ValueError(f"Incorrect image extension: {relative}")
                width, height = original.size
                target = source
                if source.suffix == ".png" and {"posts", "writeups"}.intersection(source.parts):
                    buffer = io.BytesIO()
                    original.save(buffer, "WEBP", lossless=True, method=6, exact=True)
                    if buffer.tell() < source.stat().st_size:
                        target = assets / "variants" / Path(relative).with_suffix(".webp")
                        target.parent.mkdir(parents=True, exist_ok=True)
                        target.write_bytes(buffer.getvalue())
                manifest[relative] = {"src": target.relative_to(assets).as_posix(), "width": width, "height": height}
        elif source.suffix.lower() == ".svg":
            dimensions = svg_dimensions(source)
            if not dimensions or min(dimensions) <= 0:
                raise ValueError(f"SVG needs positive intrinsic dimensions or a viewBox: {relative}")
            manifest[relative] = {"src": relative, "width": dimensions[0], "height": dimensions[1]}
    return manifest


def image_files(assets: Path) -> dict[str, Path]:
    return {path.relative_to(assets).as_posix(): path for path in assets.rglob("*")
            if path.is_file() and path.suffix.lower() in RASTER | {".svg"}}


def png_content(path: Path) -> tuple:
    """Compare lossless content, independent of the wheel's zlib implementation."""
    with Image.open(path) as image:
        if image.format != "PNG" or image.n_frames != 1:
            raise ValueError("Expected a static PNG export")
        image.verify()
    with Image.open(path) as image:
        pixels = image.tobytes()  # Load metadata following the image data, too.
        return image.mode, image.size, image.info, image.getpalette(), pixels


def equivalent_export(expected: Path, published: Path) -> bool:
    if expected.read_bytes() == published.read_bytes():
        return True
    if expected.suffix.lower() != ".png":
        return False
    # Pillow's Python wheels can bundle zlib or zlib-ng. Their compressed PNG
    # bytes differ even with the same Pillow version and identical pixels.
    try:
        return png_content(expected) == png_content(published)
    except (OSError, SyntaxError, ValueError):
        return False


def compare_exports(expected: Path, manifest: dict) -> None:
    published_manifest = json.loads(MANIFEST.read_text())
    issues = []
    missing = sorted(manifest.keys() - published_manifest.keys())
    extra = sorted(published_manifest.keys() - manifest.keys())
    changed = sorted(key for key in manifest.keys() & published_manifest.keys()
                     if manifest[key] != published_manifest[key])
    for label, paths in (("Missing manifest entries", missing), ("Unexpected manifest entries", extra),
                         ("Outdated image descriptors", changed)):
        if paths:
            issues.append(f"{label}: {', '.join(paths)}")
    expected_files, published_files = image_files(expected), image_files(ASSETS)
    for logical, path in expected_files.items():
        published = published_files.get(logical)
        if published is None:
            issues.append(f"Missing image export: {logical}")
        elif not equivalent_export(path, published):
            issues.append(f"Stale image export: {logical}")
    for logical in sorted(published_files.keys() - expected_files.keys()):
        issues.append(f"Orphan image export: {logical}")
    if issues:
        raise ValueError("\n".join(issues) + "\nRun scripts/images/export.py with the locked dependencies to regenerate exports.")


def check(font_dir: Path = FONT_DIR) -> None:
    with tempfile.TemporaryDirectory(prefix="image-exports-check-") as directory:
        expected = Path(directory)
        manifest = rebuild(expected, font_dir)
        compare_exports(expected, manifest)
    print(f"Verified {len(manifest)} image descriptors and reproducible image exports.")


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true", help="Rebuild in a temporary directory and compare every descriptor and export without writing to the repository.")
    parser.add_argument("--font-dir", type=Path, default=FONT_DIR)
    args = parser.parse_args()
    if args.check:
        check(args.font_dir)
        return
    with tempfile.TemporaryDirectory(prefix="image-exports-") as directory:
        expected = Path(directory)
        manifest = rebuild(expected, args.font_dir)
        expected_files = image_files(expected)
        for logical in image_files(ASSETS).keys() - expected_files.keys():
            (ASSETS / logical).unlink()
        for logical, source in expected_files.items():
            target = ASSETS / logical
            target.parent.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, target)
        MANIFEST.write_text(json.dumps(manifest, indent=2, sort_keys=True) + "\n")
    print(f"Exported {len(manifest)} image descriptors and their public images.")


if __name__ == "__main__":
    main()
