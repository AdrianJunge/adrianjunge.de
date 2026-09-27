"""Small authoring regressions; published exports are checked by --check."""

from pathlib import Path
import json
import tempfile
import unittest
from unittest.mock import patch

from PIL import Image

import export


class ImageExportTest(unittest.TestCase):
    def fixture(self, root):
        originals, assets = root / "originals", root / "assets"
        source = originals / "example.png"
        originals.mkdir()
        assets.mkdir()
        Image.new("RGB", (32, 16), "red").save(source)
        manifest = root / "manifest.json"
        return originals, assets, source, manifest

    def publish_fixture(self, root):
        output = root / "rebuilt"
        manifest = export.rebuild(output, export.FONT_DIR)
        for logical, source in export.image_files(output).items():
            target = export.ASSETS / logical
            target.parent.mkdir(parents=True, exist_ok=True)
            target.write_bytes(source.read_bytes())
        export.MANIFEST.write_text(json.dumps(manifest))
        return manifest

    def test_check_rebuilds_without_modifying_sources_or_published_exports(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets), patch.object(export, "MANIFEST", manifest):
                self.publish_fixture(root)
                before = {path: path.read_bytes() for path in root.rglob("*") if path.is_file()}
                export.check()
                self.assertEqual(before, {path: path.read_bytes() for path in root.rglob("*") if path.is_file()})

    def test_missing_manifest_entry_fails_even_when_images_exist(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets), patch.object(export, "MANIFEST", manifest):
                descriptors = self.publish_fixture(root)
                del descriptors["example.png"]
                manifest.write_text(json.dumps(descriptors))
                with self.assertRaisesRegex(ValueError, "Missing manifest entries: example.png"):
                    export.check()

    def test_same_dimensions_changed_original_fails_until_exports_are_rebuilt(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets), patch.object(export, "MANIFEST", manifest):
                self.publish_fixture(root)
                Image.new("RGB", (32, 16), "blue").save(source)
                with self.assertRaisesRegex(ValueError, "Stale image export: example.png"):
                    export.check()

    def test_changed_screenshot_fails_when_its_lossless_variant_is_stale(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            screenshot = assets / "posts/screenshot.png"
            screenshot.parent.mkdir()
            Image.new("RGB", (400, 400), "red").save(screenshot)
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets), patch.object(export, "MANIFEST", manifest):
                self.publish_fixture(root)
                Image.new("RGB", (400, 400), "blue").save(screenshot)
                with self.assertRaisesRegex(ValueError, "Stale image export: variants/posts/screenshot.webp"):
                    export.check()

    def test_new_asset_missing_variant_and_orphan_variant_are_reported(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets), patch.object(export, "MANIFEST", manifest):
                self.publish_fixture(root)
                Image.new("RGB", (30, 30), "green").save(assets / "new.png")
                (assets / "variants/example-32.webp").unlink()
                Image.new("RGB", (30, 30), "green").save(assets / "variants/orphan.webp")
                with self.assertRaises(ValueError) as failure:
                    export.check()
                self.assertIn("Missing manifest entries: new.png", str(failure.exception))
                self.assertIn("Missing image export: variants/example-32.webp", str(failure.exception))
                self.assertIn("Orphan image export: variants/orphan.webp", str(failure.exception))

    def test_changed_svg_original_fails_even_when_dimensions_are_unchanged(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            vector = originals / "icon.svg"
            vector.write_text('<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10"><path fill="red" d="M0 0h10v10H0z"/></svg>')
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets), patch.object(export, "MANIFEST", manifest):
                self.publish_fixture(root)
                vector.write_text(vector.read_text().replace('fill="red"', 'fill="blue"'))
                with self.assertRaisesRegex(ValueError, "Stale image export: icon.svg"):
                    export.check()

    def test_incorrect_file_extension_is_rejected(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            screenshot = assets / "posts/wrong.png"
            screenshot.parent.mkdir()
            Image.new("RGB", (30, 30), "green").save(screenshot, format="JPEG")
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets):
                with self.assertRaisesRegex(ValueError, "Incorrect image extension: posts/wrong.png"):
                    export.rebuild(root / "rebuilt", export.FONT_DIR)

    def test_svg_without_dimensions_cannot_silently_escape_the_manifest(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            originals, assets, source, manifest = self.fixture(root)
            (assets / "unsized.svg").write_text('<svg xmlns="http://www.w3.org/2000/svg"><circle r="5"/></svg>')
            with patch.object(export, "ORIGINALS", originals), patch.object(export, "ASSETS", assets):
                with self.assertRaisesRegex(ValueError, "SVG needs positive intrinsic dimensions or a viewBox: unsized.svg"):
                    export.rebuild(root / "rebuilt", export.FONT_DIR)

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
