#!/usr/bin/env python3
"""Build, verify, or restore the four bundled, offline lesson ZIP files."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import sqlite3
import tempfile
import zipfile

ROOT = Path(__file__).resolve().parents[1]
FORMAT_VERSION = 1
LIMITS = {"mp3": 4 * 1024 * 1024, "lrc": 64 * 1024}


def digest(data):
    return hashlib.sha256(data).hexdigest()


def expected_files(database):
    books = {book: [] for book in range(1, 5)}
    with sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True) as connection:
        rows = connection.execute(
            "SELECT book_id, name FROM play_list_sentences ORDER BY book_id, name"
        )
        for book, name in rows:
            if book not in books or not isinstance(name, str) or not name.startswith(f"N{book}_"):
                raise ValueError(f"Invalid sentence: {book}, {name!r}")
            if any(part in name for part in ("/", "\\", "\x00")):
                raise ValueError(f"Unsafe sentence name: {name!r}")
            for extension in LIMITS:
                books[book].append(f"{extension}/{name}.{extension}")
    for book, files in books.items():
        if not files or len(files) != len(set(files)):
            raise ValueError(f"Book {book} is empty or has duplicate sentence names")
        books[book] = sorted(files)
    return books


def validate_content(path, data):
    extension = path.split("/", 1)[0]
    if not data or len(data) > LIMITS[extension]:
        raise ValueError(f"Empty or oversized resource: {path}")
    if extension == "lrc":
        text = data.decode("utf-8")
        if "\uff0d" not in text:
            raise ValueError(f"Missing English/Chinese separator: {path}")


def build(database, source, output):
    books = expected_files(database)
    expected = {path for files in books.values() for path in files}
    actual = {
        path.relative_to(source).as_posix()
        for path in source.rglob("*")
        if path.is_file() and not any(part.startswith(".") for part in path.relative_to(source).parts)
    }
    if actual != expected:
        raise ValueError(
            f"Source mismatch: missing={sorted(expected - actual)[:5]}, "
            f"unexpected={sorted(actual - expected)[:5]}"
        )
    output.parent.mkdir(parents=True, exist_ok=True)
    manifest = {
        "format_version": FORMAT_VERSION,
        "database_sha256": digest(database.read_bytes()),
        "packs": [],
    }
    with tempfile.TemporaryDirectory(prefix="lesson-packs-", dir=output.parent) as temporary:
        staging = Path(temporary)
        for book, paths in books.items():
            filename = f"book{book}.zip"
            records = []
            with zipfile.ZipFile(staging / filename, "w") as archive:
                for path in paths:
                    data = (source / path).read_bytes()
                    validate_content(path, data)
                    info = zipfile.ZipInfo(path, date_time=(1980, 1, 1, 0, 0, 0))
                    info.create_system = 3
                    info.external_attr = 0o100644 << 16
                    info.compress_type = zipfile.ZIP_STORED if path.startswith("mp3/") else zipfile.ZIP_DEFLATED
                    archive.writestr(info, data, compresslevel=9)
                    records.append({"path": path, "bytes": len(data), "sha256": digest(data)})
            manifest["packs"].append({
                "book_id": book,
                "file": filename,
                "sha256": digest((staging / filename).read_bytes()),
                "sentence_count": len(paths) // 2,
                "files": records,
            })
        (staging / "manifest.json").write_text(
            json.dumps(manifest, ensure_ascii=True, indent=2) + "\n", encoding="utf-8"
        )
        verify(database, staging, source)
        output.mkdir(parents=True, exist_ok=True)
        for filename in [f"book{book}.zip" for book in books] + ["manifest.json"]:
            os.replace(staging / filename, output / filename)
    print(f"Built four offline packs ({len(expected)} resources) in {output}")


def verify(database, output, source=None):
    books = expected_files(database)
    manifest = json.loads((output / "manifest.json").read_text(encoding="utf-8"))
    if manifest["format_version"] != FORMAT_VERSION or manifest["database_sha256"] != digest(database.read_bytes()):
        raise ValueError("Manifest format or bundled database checksum mismatch")
    packs = manifest["packs"]
    if len(packs) != 4 or {pack["book_id"] for pack in packs} != set(books):
        raise ValueError("Manifest must contain exactly four books")
    count = 0
    for pack in packs:
        book = pack["book_id"]
        if pack["file"] != f"book{book}.zip" or pack["sentence_count"] != len(books[book]) // 2:
            raise ValueError(f"Invalid pack metadata for book {book}")
        path = output / pack["file"]
        if digest(path.read_bytes()) != pack["sha256"]:
            raise ValueError(f"ZIP checksum mismatch: {path.name}")
        records = pack["files"]
        if sorted(record["path"] for record in records) != books[book]:
            raise ValueError(f"Manifest entries mismatch for book {book}")
        with zipfile.ZipFile(path) as archive:
            if sorted(archive.namelist()) != books[book]:
                raise ValueError(f"ZIP entries mismatch for book {book}")
            for record in records:
                entry = record["path"]
                info = archive.getinfo(entry)
                extension = entry.split("/", 1)[0]
                if (info.file_size > LIMITS[extension] or info.flag_bits & 1 or
                        info.compress_type not in (zipfile.ZIP_STORED, zipfile.ZIP_DEFLATED)):
                    raise ValueError(f"Unsupported ZIP entry: {entry}")
                data = archive.read(entry)
                validate_content(entry, data)
                if len(data) != record["bytes"] or digest(data) != record["sha256"]:
                    raise ValueError(f"Entry checksum mismatch: {entry}")
                if source is not None and data != (source / entry).read_bytes():
                    raise ValueError(f"Source bytes mismatch: {entry}")
                count += 1
    print(f"Verified {count} resources across four books")
    return manifest


def restore(database, output, source):
    manifest = verify(database, output)
    # Only database-validated paths are written; never use extractall on an arbitrary ZIP.
    for pack in manifest["packs"]:
        with zipfile.ZipFile(output / pack["file"]) as archive:
            for record in pack["files"]:
                destination = source / record["path"]
                data = archive.read(record["path"])
                if destination.exists() and destination.read_bytes() != data:
                    raise ValueError(f"Refusing to overwrite changed source: {destination}")
                destination.parent.mkdir(parents=True, exist_ok=True)
                destination.write_bytes(data)
    print(f"Restored editable sources to {source}")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    modes = parser.add_mutually_exclusive_group()
    modes.add_argument("--verify", action="store_true")
    modes.add_argument("--restore", action="store_true")
    parser.add_argument("--database", type=Path, default=ROOT / "NCE_ALL/data/NCE.db")
    parser.add_argument("--source", type=Path, default=ROOT / "ResourceSources/lessons")
    parser.add_argument("--output", type=Path, default=ROOT / "NCE_ALL/data/lesson-packs")
    args = parser.parse_args()
    try:
        if args.verify:
            verify(args.database, args.output, args.source if args.source.exists() else None)
        elif args.restore:
            restore(args.database, args.output, args.source)
        else:
            build(args.database, args.source, args.output)
    except (OSError, ValueError, KeyError, sqlite3.Error, zipfile.BadZipFile) as error:
        parser.exit(1, f"Resource pack error: {error}\n")


if __name__ == "__main__":
    main()
