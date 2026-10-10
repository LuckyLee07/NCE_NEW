import importlib.util
import json
from pathlib import Path
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "split_word_image_atlas.py"
SPEC = importlib.util.spec_from_file_location("atlas_splitter", SCRIPT)
splitter = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(splitter)


class WordAtlasTests(unittest.TestCase):
    def manifest(self):
        return {"format_version": 1, "id": "atlas-001", "grid": [2, 2], "source": "atlas-001.png",
                "cells": [{"word": word, "index": index, "source": f"atlas-001-{index}.png"}
                          for index, word in enumerate(["cloakroom", "lamp-post", "fire extinguisher", "windscreen"])]}

    def test_fixed_cell_order(self):
        splitter.validate_manifest(self.manifest())
        manifest = self.manifest()
        manifest["cells"][0]["index"] = 3
        with self.assertRaises(ValueError):
            splitter.validate_manifest(manifest)

    def test_duplicate_words_and_traversal(self):
        manifest = self.manifest()
        manifest["cells"][0]["word"] = "windscreen"
        with self.assertRaises(ValueError):
            splitter.validate_manifest(manifest)
        manifest = self.manifest()
        manifest["source"] = "../../outside.png"
        with self.assertRaises(ValueError):
            splitter.validate_manifest(manifest)

    def test_recorded_batch(self):
        manifest = json.loads((SCRIPT.parents[1] / "ContentPipeline/word-images/atlas-001.json").read_text())
        splitter.validate_manifest(manifest)
        self.assertEqual(manifest["mode"], "built-in image_gen")

    def test_explicit_related_word_alias(self):
        manifest = self.manifest()
        manifest["cells"][0]["also_words"] = ["changing room"]
        splitter.validate_manifest(manifest)
        for invalid in [["windscreen"], ["../outside"], "changing room", ["alias", "alias"]]:
            manifest["cells"][0]["also_words"] = invalid
            with self.assertRaises(ValueError):
                splitter.validate_manifest(manifest)

    def test_completed_production_plan(self):
        root = SCRIPT.parents[1]
        pipeline = root / "ContentPipeline/word-images"
        plan = json.loads((pipeline / "illustration-plan.json").read_text())
        assets = {asset["word"]: asset for asset in json.loads(
            (root / "Docs/word-resources/generated-images.json").read_text())["assets"]}
        self.assertEqual(len(plan["batches"]), 25)
        words = []
        for batch in plan["batches"]:
            manifest = json.loads((pipeline / (batch["id"] + ".json")).read_text())
            splitter.validate_manifest(manifest)
            self.assertEqual(manifest["mode"], "built-in image_gen")
            self.assertEqual([(cell["index"], cell["word"]) for cell in manifest["cells"]],
                             [(cell["index"], cell["word"]) for cell in batch["cells"]])
            for cell in manifest["cells"]:
                words.append(cell["word"])
                asset = assets[cell["word"]]
                self.assertEqual(asset["kind"], "ai_illustration")
                # A recorded semantic correction may replace a production-plan draft.
                if cell["word"] == "glider":
                    self.assertEqual(asset["generated_source"], "atlas-029-0.png")
                else:
                    self.assertEqual(asset["generated_source"], cell["source"])
                self.assertEqual((asset["width"], asset["height"]), (128, 128))
        self.assertEqual(len(words), 100)
        self.assertEqual(len(set(words)), 100)


if __name__ == "__main__":
    unittest.main()
