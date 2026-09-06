"""Small authoring regressions; published exports are checked by --check."""

from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

import export


class ImageExportTest(unittest.TestCase):
    def test_jpeg_original_remains_unchanged_and_exports_valid_variants(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets = root / "originals", root / "assets"
            source = originals / "ctf/example.jpg"
            source.parent.mkdir(parents=True)
            Image.new("RGB", (240, 120), "#346891").save(source)
            original_bytes = source.read_bytes()
            manifest = {}
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets):
                export.export_logo(source, manifest)
            self.assertEqual(original_bytes, source.read_bytes())
            with Image.open(assets / "ctf/example.jpg") as fallback:
                self.assertEqual("JPEG", fallback.format)
            entry = manifest["ctf/example.jpg"]
            self.assertEqual((240, 120), (entry["width"], entry["height"]))
            for variant in entry["variants"]:
                with Image.open(assets / variant["path"]) as image:
                    self.assertEqual("WEBP", image.format)
                    self.assertEqual(variant["width"], image.width)

    def test_transparent_logo_is_not_cropped_or_upscaled(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets = root / "originals", root / "assets"
            originals.mkdir()
            source = originals / "example.png"
            image = Image.new("RGBA", (64, 32), (0, 0, 0, 0))
            image.putpixel((32, 16), (255, 255, 255, 255))
            image.save(source)
            manifest = {}
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets):
                export.export_logo(source, manifest)
            self.assertEqual(1, len(manifest["example.png"]["variants"]))
            with Image.open(assets / manifest["example.png"]["src"]) as result:
                self.assertEqual((64, 32), result.size)
                self.assertEqual(0, result.convert("RGBA").getpixel((0, 0))[3])
                self.assertEqual(255, result.convert("RGBA").getpixel((32, 16))[3])


if __name__ == "__main__":
    unittest.main()
