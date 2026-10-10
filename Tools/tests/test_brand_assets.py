import hashlib
import json
from pathlib import Path
import unittest

from PIL import Image

ROOT = Path(__file__).resolve().parents[2]
REPORT = ROOT / "Docs/branding/asset-report.json"


class BrandAssetTests(unittest.TestCase):
    def setUp(self):
        self.report = json.loads(REPORT.read_text())

    def test_exported_assets_are_opaque_decodable_and_match_manifest(self):
        self.assertEqual(len(self.report["assets"]), 27)
        total = 0
        for record in self.report["assets"]:
            path = ROOT / record["path"]
            data = path.read_bytes()
            self.assertEqual(hashlib.sha256(data).hexdigest(), record["sha256"], path)
            self.assertEqual(len(data), record["bytes"], path)
            total += len(data)
            with Image.open(path) as image:
                image.load()
                self.assertEqual(image.size, (record["width"], record["height"]), path)
                self.assertEqual(image.format, record["format"], path)
                self.assertEqual(image.mode, "RGB", path)
                self.assertNotIn("transparency", image.info, path)
                self.assertGreater(max(image.getextrema()[0]) - min(image.getextrema()[0]), 20, path)
        self.assertEqual(total, self.report["total_app_asset_bytes"])
        self.assertLess(total, self.report["previous_app_asset_bytes"])

    def test_every_app_icon_slot_has_the_correct_size(self):
        directory = ROOT / "NCE_ALL/Images.xcassets/AppIcon.appiconset"
        catalog = json.loads((directory / "Contents.json").read_text())
        for slot in catalog["images"]:
            pixels = round(float(slot["size"].split("x")[0]) * float(slot["scale"][:-1]))
            with Image.open(directory / slot["filename"]) as image:
                self.assertEqual(image.size, (pixels, pixels), slot)
        self.assertEqual(len(list(directory.glob("*.png"))), 19)

    def test_approved_ink_icon_is_full_bleed_without_preview_margins(self):
        design = json.loads((ROOT / "ContentPipeline/branding/design-spec.json").read_text())
        self.assertEqual(design["revision"], "20261006-approved-ink")
        self.assertEqual(design["status"], "approved_production_artwork")
        self.assertEqual(design["approved_designs"]["icon_placement"],
                         "custom NCE centered across four book spines")
        self.assertEqual(design["app_interface_languages"], ["zh-Hans", "zh-Hant", "ja", "ko"])
        self.assertEqual([asset["id"] for asset in design["assets"]],
                         ["icon", "book1", "book2", "book3", "book4"])
        directory = ROOT / "NCE_ALL/Images.xcassets/AppIcon.appiconset"
        for path in directory.glob("*.png"):
            with Image.open(path) as image:
                for x, y in [(0, 0), (image.width - 1, 0),
                             (0, image.height - 1), (image.width - 1, image.height - 1)]:
                    red, green, blue = image.getpixel((x, y))
                    self.assertGreater(red, green + 35, path)
                    self.assertGreater(red, blue + 35, path)
                    self.assertLess(red, 190, path)

    def test_four_covers_are_shared_and_previous_sources_preserved(self):
        controller = (ROOT / "NCE_ALL/Classes/FirstViewController.m").read_text()
        project = (ROOT / "NCE_ALL.xcodeproj/project.pbxproj").read_text()
        self.assertIn('@"book%d_iPad.png"', controller)
        self.assertIn('@"book%d.jpg"', controller)
        self.assertNotIn("ContentPipeline/branding", project)
        self.assertFalse(self.report["home_layout_changed"])
        self.assertFalse(self.report["english_interface_added"])
        self.assertEqual(len(self.report["previous_assets"]), 25)
        for record in self.report["previous_assets"] + self.report["sources"]:
            path = ROOT / record["path"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), record["sha256"], path)
        cover_hashes = []
        for book in range(1, 5):
            for name in [f"book{book}.jpg", f"book{book}_iPad.png"]:
                self.assertIn(name + " in Resources", project)
            with Image.open(ROOT / f"NCE_ALL/images/book{book}.jpg") as image:
                self.assertEqual(image.size, (540, 756))
                cover_hashes.append(hashlib.sha256(image.tobytes()).hexdigest())
            with Image.open(ROOT / f"NCE_ALL/images/book{book}_iPad.png") as image:
                self.assertEqual(image.size, (630, 882))
        self.assertEqual(len(set(cover_hashes)), 4)


if __name__ == "__main__":
    unittest.main()
