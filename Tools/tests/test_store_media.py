import hashlib
import json
import os
from pathlib import Path
import unittest

from PIL import Image
from Tools import export_store_media as exporter

ROOT = Path(__file__).resolve().parents[2]
ASSETS = Path(os.environ.get("NCE_STORE_MEDIA_ROOT", ROOT / "StoreAssets/1.3"))
LOCALES = {"zh-Hans", "zh-Hant", "ja", "ko", "en-US", "en-CA"}
SCENES = {"01-home", "02-lesson", "03-word", "04-practice", "05-wordbook"}


class PreviewExportTests(unittest.TestCase):
    def test_filter_has_no_framing_cropping_or_text(self):
        for label, spec in exporter.DEVICE_SPECS.items():
            filters = exporter.preview_filter(label, 12.345678)
            width, height = spec["video"]
            self.assertIn(f"scale={width}:{height}:flags=lanczos", filters)
            self.assertIn("trim=start=12.345678:duration=4.8", filters)
            self.assertIn("setsar=1", filters)
            for forbidden in ("pad=", "crop=", "drawtext=", "overlay="):
                self.assertNotIn(forbidden, filters)

    def test_native_frame_comparison_detects_added_framing(self):
        native = Image.new("RGB", (120, 160), "green")
        self.assertEqual(exporter.verify_native_frame(native, native)["max_edge_rgb_error"], 0)
        framed = Image.new("RGB", native.size, "white")
        framed.paste(native.resize((100, 130)), (10, 20))
        with self.assertRaisesRegex(AssertionError, "full-frame native capture"):
            exporter.verify_native_frame(framed, native)
        with self.assertRaisesRegex(AssertionError, "dimensions differ"):
            exporter.verify_native_frame(native.resize((120, 158)), native)


@unittest.skipUnless((ASSETS / "manifest.json").exists(), "Generate the store media first")
class StoreMediaTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.manifest = json.loads((ASSETS / "manifest.json").read_text())

    def test_complete_locale_device_matrix(self):
        screenshots = self.manifest["screenshots"]
        videos = self.manifest["videos"]
        self.assertEqual(len(screenshots), 60)
        self.assertEqual(len(videos), 12)
        expected = {(language, device, scene) for language in LOCALES for device in ("iphone", "ipad") for scene in SCENES}
        self.assertEqual({(item["locale"], item["device"], item["scene"]) for item in screenshots}, expected)
        self.assertEqual({(item["locale"], item["device"]) for item in videos}, {(language, device) for language in LOCALES for device in ("iphone", "ipad")})

    def test_files_dimensions_hashes_and_no_transparency(self):
        for item in self.manifest["screenshots"] + self.manifest["videos"]:
            path = ASSETS / item["path"]
            self.assertTrue(path.is_file(), path)
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), item["sha256"])
            if path.suffix == ".png":
                with Image.open(path) as image:
                    self.assertEqual(image.size, (1290, 2796) if item["device"] == "iphone" else (2048, 2732))
                    if image.mode == "RGBA":
                        self.assertEqual(image.getextrema()[3], (255, 255))

    def test_preview_specs_and_real_scene_provenance(self):
        for item in self.manifest["videos"]:
            self.assertTrue(15 <= item["duration_seconds"] <= 30)
            self.assertLessEqual(item["bytes"], 500 * 1024 * 1024)
            self.assertLessEqual(item["fps"], 30)
            self.assertEqual((item["width"], item["height"]), (886, 1920) if item["device"] == "iphone" else (1200, 1600))
            self.assertEqual(item["codec"], "H.264")
            self.assertTrue(item["all_frames_decode"])
            self.assertTrue(10_000_000 <= item["video_bit_rate"] <= 12_000_000)
            self.assertGreater(item["actual_app_motion_changed_pixel_fraction"]["02-lesson"], 0.003)
            self.assertGreater(item["actual_app_motion_changed_pixel_fraction"]["05-wordbook"], 0.003)
            self.assertEqual({edit["scene"] for edit in item["edits"]}, SCENES)
            self.assertTrue(all(edit["source_offset_seconds"] >= 0 for edit in item["edits"]))

    def test_full_frame_export_provenance(self):
        if self.manifest.get("preview_layout") != exporter.PREVIEW_LAYOUT:
            self.skipTest("Historical framed media is preserved separately")
        self.assertEqual(set(self.manifest["upload_locales"]), LOCALES - {"en-US"})
        for item in self.manifest["videos"]:
            self.assertEqual(item["preview_layout"], exporter.PREVIEW_LAYOUT)
            self.assertFalse(item["added_framing"])
            self.assertFalse(item["text_overlays"])
            self.assertEqual(item["native_framing_validation"]["status"], "passed")
            self.assertEqual(item["native_framing_validation"]["sampled_scenes"], 5)
            self.assertEqual(set(item["native_framing_validation"]["source_comparison"]), SCENES)
            for edit in item["edits"]:
                self.assertEqual(edit["video_filter"], exporter.preview_filter(item["device"], edit["source_offset_seconds"]))
            if item["locale"].startswith("en-"):
                original = ASSETS / "upload/zh-Hans" / item["device"] / "app-preview.mp4"
                self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), item["sha256"])

    def test_english_storefront_does_not_invent_english_ui(self):
        for item in self.manifest["screenshots"] + self.manifest["videos"]:
            if item["locale"] in {"en-US", "en-CA"}:
                self.assertEqual(item["actual_ui_locale"], "zh-Hans")
                if "scene" in item:
                    original = ASSETS / "upload/zh-Hans" / item["device"] / f"{item['scene']}.png"
                    self.assertEqual(hashlib.sha256(original.read_bytes()).hexdigest(), item["sha256"])

    def test_passed_independent_capture_and_no_upload(self):
        self.assertFalse(self.manifest["production_records_touched"])
        self.assertFalse(self.manifest["uploaded"])
        self.assertFalse(self.manifest["review_submitted"])
        self.assertEqual(len(self.manifest["runs"]), 2)
        for run in self.manifest["runs"]:
            self.assertEqual(run["summary"]["result"], "Passed")
            self.assertEqual(run["summary"]["failedTests"], 0)

    def test_poster_reference_matrix_and_files(self):
        posters = self.manifest["posters"]
        self.assertEqual(len(posters), 12)
        self.assertEqual({(item["locale"], item["device"]) for item in posters},
                         {(language, device) for language in LOCALES for device in ("iphone", "ipad")})
        for item in posters:
            path = ASSETS / item["path"]
            self.assertEqual(hashlib.sha256(path.read_bytes()).hexdigest(), item["sha256"])
            self.assertTrue(item["reference_only"])
            with Image.open(path) as poster:
                self.assertEqual(poster.size, (886, 1920) if item["device"] == "iphone" else (1200, 1600))
                self.assertEqual(poster.mode, "RGB")


if __name__ == "__main__":
    unittest.main()
