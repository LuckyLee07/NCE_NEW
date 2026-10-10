import importlib.util
from pathlib import Path
import sqlite3
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / "build_lesson_packs.py"
SPEC = importlib.util.spec_from_file_location("packs", SCRIPT)
packs = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(packs)


class PackTests(unittest.TestCase):
    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.root = Path(self.temporary.name)
        self.database = self.root / "NCE.db"
        self.source = self.root / "source"
        self.output = self.root / "packs"
        with sqlite3.connect(self.database) as connection:
            connection.execute("CREATE TABLE play_list_sentences (book_id INTEGER, name TEXT)")
            for book in range(1, 5):
                name = f"N{book}_L1_sentence"
                connection.execute("INSERT INTO play_list_sentences VALUES (?, ?)", (book, name))
                for extension, data in [("mp3", b"ID3-test-audio"), ("lrc", "Hello\uff0dTranslation".encode())]:
                    path = self.source / extension / f"{name}.{extension}"
                    path.parent.mkdir(parents=True, exist_ok=True)
                    path.write_bytes(data)

    def tearDown(self):
        self.temporary.cleanup()

    def test_reproducible_build_and_source_free_verification(self):
        packs.build(self.database, self.source, self.output)
        second = self.root / "second"
        packs.build(self.database, self.source, second)
        for path in self.output.iterdir():
            self.assertEqual(path.read_bytes(), (second / path.name).read_bytes())
        packs.verify(self.database, self.output)

    def test_restore_and_protect_local_edits(self):
        packs.build(self.database, self.source, self.output)
        restored = self.root / "restored"
        packs.restore(self.database, self.output, restored)
        for path in self.source.rglob("*"):
            if path.is_file():
                self.assertEqual(path.read_bytes(), (restored / path.relative_to(self.source)).read_bytes())
        next(restored.rglob("*.lrc")).write_bytes(b"local edits")
        with self.assertRaisesRegex(ValueError, "Refusing to overwrite"):
            packs.restore(self.database, self.output, restored)

    def test_missing_and_extra_resources(self):
        extra = self.source / "mp3/extra.mp3"
        extra.write_bytes(b"extra")
        with self.assertRaisesRegex(ValueError, "Source mismatch"):
            packs.build(self.database, self.source, self.output)
        extra.unlink()
        next(self.source.rglob("*.mp3")).unlink()
        with self.assertRaisesRegex(ValueError, "Source mismatch"):
            packs.build(self.database, self.source, self.output)

    def test_duplicate_database_names(self):
        with sqlite3.connect(self.database) as connection:
            connection.execute("INSERT INTO play_list_sentences VALUES (1, 'N1_L1_sentence')")
        with self.assertRaisesRegex(ValueError, "duplicate"):
            packs.build(self.database, self.source, self.output)

    def test_corrupt_pack(self):
        packs.build(self.database, self.source, self.output)
        archive = self.output / "book1.zip"
        archive.write_bytes(archive.read_bytes() + b"tampered")
        with self.assertRaisesRegex(ValueError, "checksum mismatch"):
            packs.verify(self.database, self.output)

    def test_invalid_text(self):
        next(self.source.rglob("*.lrc")).write_bytes(b"missing translation delimiter")
        with self.assertRaisesRegex(ValueError, "separator"):
            packs.build(self.database, self.source, self.output)


if __name__ == "__main__":
    unittest.main()
