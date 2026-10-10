import importlib.util
import json
from pathlib import Path
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "build_word_images.py"
SPEC = importlib.util.spec_from_file_location("image_builder", SCRIPT)
builder = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(builder)


class WordImageBuildTests(unittest.TestCase):
    def test_review_metadata_preserves_manual_notes(self):
        old = "| [x] | word | old meaning | context | [JPG](old.jpg) | yes | keep my note |\n"
        fresh = ["| [ ] | word | new meaning \\| extra | diagram | [JPG](new.jpg) | no |"]
        updated = builder.sync_review_rows(old, fresh)
        self.assertIn("| [x] | word | new meaning \\| extra | diagram |", updated)
        self.assertIn("| no | keep my note |", updated)

    def test_semantic_repairs_preserve_original_path(self):
        baseline = {"words": [{"word": "may", "image": {"path": "jpg/may.jpg", "status": "exact"}},
                              {"word": "new", "image": {"path": None, "status": "missing"}}]}
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "repairs.json"
            path.write_text(json.dumps({"format_version": 1, "repairs": {
                "may": {"previous_path": "jpg/may.jpg", "note": "wrong sense"}}}))
            self.assertEqual({row["word"] for row in builder.image_words(baseline, path)}, {"may", "new"})
            path.write_text(json.dumps({"format_version": 1, "repairs": {
                "may": {"previous_path": "jpg/May.jpg", "note": "wrong sense"}}}))
            with self.assertRaises(ValueError):
                builder.image_words(baseline, path)

    def test_safe_case_distinct_filenames(self):
        self.assertNotEqual(builder.filename("Endeavour").casefold(), builder.filename("endeavour").casefold())
        for word in ["maitre d'hotel", "AT&T", "../file", "a\\b", "St.Petersbrug"]:
            self.assertNotIn("/", builder.filename(word))
            self.assertNotIn("\\", builder.filename(word))
            self.assertTrue(builder.filename(word).endswith(".jpg"))

    def test_caption_and_recipes(self):
        self.assertEqual(builder.clean_caption("a.& n. French person"), "French person")
        recipes = builder.load_recipes()
        self.assertEqual(recipes["handbag"]["icons"], ["1f45c"])
        self.assertEqual(recipes["praying mantis"]["kind"], "ai_illustration")
        self.assertNotEqual(recipes["Endeavour"], recipes["endeavour"])
        with tempfile.TemporaryDirectory() as temporary:
            path = Path(temporary) / "recipes.txt"
            path.write_text("illustration;1f45c;handbag\ncontext;1f45c;handbag\n")
            with self.assertRaises(ValueError):
                builder.load_recipes(path)


if __name__ == "__main__":
    unittest.main()
