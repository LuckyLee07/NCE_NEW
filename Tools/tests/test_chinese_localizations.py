import importlib.util
import json
from pathlib import Path
import re
import unittest

from PIL import Image

SCRIPT = Path(__file__).resolve().parents[1] / "build_chinese_localizations.py"
SPEC = importlib.util.spec_from_file_location("chinese_localizations", SCRIPT)
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


class ChineseLocalizationTests(unittest.TestCase):
    def test_complete_text_coverage_and_unchanged_sources(self):
        values, counts, _, _ = builder.source_texts()
        overlay = json.loads((builder.DATA / "localizations/zh-Hant.json").read_text())
        overrides = builder.read_overrides()
        self.assertEqual(counts["lesson_records"], 276)
        self.assertEqual(counts["sentence_records"], 4445)
        self.assertEqual(counts["word_records"], 3332)
        self.assertEqual(set(overlay["texts"]), values)
        for text in values:
            self.assertEqual(overlay["texts"][text], builder.convert(text, overrides["texts"]))
        self.assertEqual(json.loads((builder.DOCS / "preserved-sources.json").read_text()), builder.preserved_sources())

    def test_ui_placeholders_and_display_names(self):
        overrides = builder.read_overrides()
        keys = builder.ui_keys()
        hans = {key: key for key in keys}
        hant = {key: builder.convert(key, {**overrides["texts"], **overrides["ui"]}) for key in keys}
        for code, strings in [("zh-Hans", hans), ("zh-Hant", hant)]:
            self.assertEqual((builder.APP / f"{code}.lproj/Localizable.strings").read_text(), builder.strings_file(strings))
        for key in keys:
            self.assertEqual(re.findall(r"%(?:@|[dflu]+)", key), re.findall(r"%(?:@|[dflu]+)", hant[key]))
        self.assertEqual(hant["设置"], "設定")
        self.assertEqual(hant["搜索单词或释义"], "搜尋單詞或釋義")
        self.assertEqual(builder.convert("n.软件", overrides["texts"]), "n.軟體")

    def test_small_decodable_images_and_no_orphan_variants(self):
        overlay = json.loads((builder.DATA / "localizations/zh-Hant.json").read_text())
        ledger = json.loads((builder.DOCS / "generated-images.json").read_text())
        self.assertEqual(overlay["images"], {asset["word"]: asset["path"] for asset in ledger["assets"]})
        paths = set()
        for asset in ledger["assets"]:
            self.assertRegex(asset["path"], r"^jpg/localized-[0-9a-f]{12}--hant\.jpg$")
            path = builder.WORDS / asset["path"]
            paths.add(path)
            self.assertEqual(builder.sha(path), asset["sha256"])
            self.assertLessEqual(path.stat().st_size, 8192)
            with Image.open(path) as image:
                image.load()
                self.assertEqual(image.format, "JPEG")
                self.assertEqual(image.size, (128, 128))
        self.assertEqual(paths, set((builder.WORDS / "jpg").glob("*--hant.jpg")))
        self.assertNotIn("hospital", overlay["images"])
        self.assertNotIn("mathematics", overlay["images"])
        self.assertIn("dignity", overlay["images"])

    def test_no_original_courses_or_runtime_converter(self):
        project = (builder.ROOT / "NCE_ALL.xcodeproj/project.pbxproj").read_text()
        self.assertNotIn("ContentPipeline", project)
        self.assertNotIn("opencc", project.lower())
        self.assertIn('developmentRegion = "zh-Hans";', project)
        self.assertIn("Localizable.strings in Resources", project)
        runtime = (builder.APP / "Utility/NCELocalization.m").read_text()
        self.assertNotIn("NSURLSession", runtime)
        self.assertNotIn("AppleLanguages", runtime)

    def test_store_metadata_drafts_within_field_limits(self):
        metadata = json.loads((builder.DOCS / "store-metadata.json").read_text())
        self.assertEqual(set(metadata["localizations"]), {"zh-Hans", "zh-Hant", "ja", "ko", "en-US"})
        self.assertEqual(metadata["primary_language"], "zh-Hans")
        for record in metadata["localizations"].values():
            for key, limit in [("name", 30), ("subtitle", 30), ("keywords", 100), ("promotional_text", 170), ("description", 4000), ("whats_new", 4000)]:
                self.assertTrue(record[key])
                self.assertLessEqual(len(record[key]), limit, key)
            self.assertNotIn("官方", record["description"])
            self.assertNotIn("AI", record["description"])

    def test_store_keywords_and_store_only_english(self):
        metadata = json.loads((builder.DOCS / "store-metadata.json").read_text())
        plan = json.loads((builder.DOCS / "aso-plan.json").read_text())
        receipt = json.loads((builder.DOCS / "app-store-connect-1.3-record.json").read_text())
        self.assertEqual(set(receipt["saved_locales"]), set(metadata["localizations"]))
        self.assertEqual(set(plan["first_release"]["locales"]), set(metadata["localizations"]))
        self.assertEqual(set(plan["first_release"]["app_interface_locales"]), {"zh-Hans", "zh-Hant", "ja", "ko"})
        self.assertEqual(receipt["existing_other_localizations_untouched"], ["en-CA"])
        self.assertIn("does not include an English-language interface", metadata["localizations"]["en-US"]["description"])
        self.assertFalse((builder.APP / "en-US.lproj").exists())
        for locale, record in metadata["localizations"].items():
            terms = record["keywords"].split(",")
            self.assertTrue(all(term and term == term.strip() for term in terms), locale)
            self.assertEqual(len(terms), len({term.casefold() for term in terms}), locale)
            title = (record["name"] + " " + record["subtitle"]).casefold()
            for term in terms:
                self.assertNotIn(term.casefold(), title, (locale, term))
            self.assertEqual(receipt["keyword_revision"]["character_counts"][locale], len(record["keywords"]), locale)


if __name__ == "__main__":
    unittest.main()
