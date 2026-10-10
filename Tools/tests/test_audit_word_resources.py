import importlib.util
import json
from pathlib import Path
import sqlite3
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "audit_word_resources.py"
SPEC = importlib.util.spec_from_file_location("word_audit", SCRIPT)
audit = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(audit)


class WordAuditTests(unittest.TestCase):
    def test_exact_and_explicit_aliases(self):
        self.assertEqual(audit.match("May", "wav", {"May.wav"}), ("May.wav", "exact"))
        self.assertEqual(audit.match("may", "wav", {"May.wav"}), ("May.wav", "case_alias"))
        self.assertEqual(audit.match("MAY", "wav", {"May.wav", "may.wav"}), (None, "ambiguous"))
        self.assertEqual(audit.match("missing", "wav", set()), (None, "missing"))

    def test_shared_words_missing_images_and_unreferenced_files(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            database = root / "db.sqlite"
            with sqlite3.connect(database) as connection:
                connection.execute("CREATE TABLE words (word_name TEXT, word_translation TEXT, book_id INTEGER, lesson_id INTEGER, order_id INTEGER)")
                connection.executemany("INSERT INTO words VALUES (?, ?, ?, ?, ?)", [
                    ("May", "month", 1, 1, 1), ("may", "modal", 1, 2, 1), ("May", "month", 2, 3, 1)
                ])
            (root / "wav").mkdir()
            (root / "jpg").mkdir()
            (root / "wav/May.wav").write_bytes(b"audio")
            (root / "wav/extra.wav").write_bytes(b"unused")
            report = audit.audit(database, root)
            self.assertEqual(report["summary"]["unique_words"], 2)
            self.assertEqual(report["summary"]["word_rows"], 3)
            self.assertEqual(report["summary"]["audio_missing"], 0)
            self.assertEqual(report["summary"]["audio_case_alias"], 1)
            self.assertEqual(report["summary"]["image_missing"], 2)
            self.assertEqual(report["unreferenced_files"]["wav"], ["extra.wav"])
            index = audit.index_from_report(report)
            self.assertEqual(index["words"]["may"]["audio"], "wav/May.wav")
            self.assertIsNone(index["words"]["may"]["image"])
            invalid = root / "decode.json"
            invalid.write_text(json.dumps({"wav": [{"file": "May.wav", "valid": False}], "jpg": []}))
            checked = audit.audit(database, root, invalid)
            self.assertEqual(checked["summary"]["audio_invalid"], 2)
            self.assertIsNone(audit.index_from_report(checked)["words"]["May"]["audio"])

    def test_generated_images_do_not_conflate_case_sensitive_meanings(self):
        with tempfile.TemporaryDirectory() as temporary:
            root = Path(temporary)
            database = root / "db.sqlite"
            with sqlite3.connect(database) as connection:
                connection.execute("CREATE TABLE words (word_name TEXT, word_translation TEXT, book_id INTEGER, lesson_id INTEGER, order_id INTEGER)")
                connection.executemany("INSERT INTO words VALUES (?, ?, ?, ?, ?)", [
                    ("Endeavour", "shuttle", 2, 1, 1), ("endeavour", "effort", 3, 1, 1)
                ])
            (root / "jpg").mkdir()
            (root / "jpg/shuttle--1.jpg").write_bytes(b"shuttle")
            (root / "jpg/effort--2.jpg").write_bytes(b"effort")
            mapping = {"format_version": 1, "images": {"Endeavour": "jpg/shuttle--1.jpg", "endeavour": "jpg/effort--2.jpg"}}
            map_path = root / "generated-image-map.json"
            map_path.write_text(json.dumps(mapping))
            report = audit.audit(database, root)
            self.assertEqual(report["summary"]["image_missing"], 0)
            self.assertEqual(report["summary"]["image_mapped"], 2)
            self.assertEqual(report["unreferenced_files"]["jpg"], [])
            self.assertNotEqual(audit.index_from_report(report)["words"]["Endeavour"]["image"], audit.index_from_report(report)["words"]["endeavour"]["image"])
            (root / "jpg/effort--2.jpg").unlink()
            self.assertEqual(audit.audit(database, root)["summary"]["image_missing"], 1)
            mapping["images"]["Endeavour"] = "jpg/../../outside.jpg"
            map_path.write_text(json.dumps(mapping))
            with self.assertRaises(ValueError):
                audit.audit(database, root)


if __name__ == "__main__":
    unittest.main()
