#!/usr/bin/env python3
"""Audit word assets using exact ZIP-safe names, with explicit legacy case aliases."""

import argparse
import hashlib
import json
from pathlib import Path
import sqlite3

ROOT = Path(__file__).resolve().parents[1]
FUNCTION_WORDS = set("a an the am is are was were be been being do does did have has had i you he she it we they me him her us them my your his its our their this that these those yes no not and or but if as at by for from in of on to with can could may might must shall should will would very much".split())


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def load_words(database):
    with sqlite3.connect(database.resolve().as_uri() + "?mode=ro", uri=True) as connection:
        records = connection.execute(
            "SELECT word_name, word_translation, book_id, lesson_id FROM words ORDER BY book_id, lesson_id, order_id"
        )
        words = {}
        for name, translation, book, lesson in records:
            if not name or any(character in name for character in ("/", "\\", "\x00")):
                raise ValueError(f"Unsafe or empty database word: {name!r}")
            words.setdefault(name, []).append({"translation": translation or "", "book_id": book, "lesson_id": lesson})
    return words


def match(name, extension, filenames):
    expected = f"{name}.{extension}"
    if expected in filenames:
        return expected, "exact"
    alternatives = sorted(filename for filename in filenames if filename.casefold() == expected.casefold())
    if len(alternatives) == 1:
        return alternatives[0], "case_alias"
    return None, "ambiguous" if alternatives else "missing"


def audit(database, resource_root, validation=None):
    words = load_words(database)
    map_path = resource_root / "generated-image-map.json"
    image_map = {}
    if map_path.exists():
        mapping = json.loads(map_path.read_text(encoding="utf-8"))
        if mapping.get("format_version") != 1 or not isinstance(mapping.get("images"), dict):
            raise ValueError("Invalid generated image map")
        for word, path in mapping["images"].items():
            if word not in words or not isinstance(path, str):
                raise ValueError(f"Invalid image mapping key or value: {word!r}")
            parts = path.split("/")
            if len(parts) != 2 or parts[0] != "jpg" or not parts[1].endswith(".jpg") or "\\" in path or any(ord(c) < 32 for c in path):
                raise ValueError(f"Unsafe generated image path: {path!r}")
            image_map[word] = parts[1]
    files = {
        extension: {path.name for path in (resource_root / extension).glob(f"*.{extension}") if path.is_file()}
        for extension in ("wav", "jpg")
    }
    invalid = {kind: set() for kind in ("wav", "jpg")}
    if validation:
        checks = json.loads(validation.read_text(encoding="utf-8"))
        for kind in invalid:
            invalid[kind] = {record["file"] for record in checks[kind] if not record["valid"]}
    records = []
    used = {kind: set() for kind in files}
    for name, references in words.items():
        record = {"word": name, "references": references}
        for kind, field in (("wav", "audio"), ("jpg", "image")):
            if kind == "jpg" and name in image_map:
                filename = image_map[name] if image_map[name] in files[kind] else None
                status = "mapped" if filename else "missing"
            else:
                filename, status = match(name, kind, files[kind])
            if filename:
                used[kind].add(filename)
                if filename in invalid[kind]:
                    status = "invalid"
            record[field] = {"path": f"{kind}/{filename}" if filename else None, "status": status}
        if record["image"]["status"] == "missing":
            record["image_action"] = "optional_function_word" if name.casefold() in FUNCTION_WORDS else "manual_review"
        records.append(record)
    summary = {"unique_words": len(words), "word_rows": sum(len(refs) for refs in words.values())}
    for kind, field in (("wav", "audio"), ("jpg", "image")):
        summary[f"{field}_files"] = len(files[kind])
        for status in ("missing", "case_alias", "ambiguous", "invalid", "mapped"):
            summary[f"{field}_{status}"] = sum(record[field]["status"] == status for record in records)
    return {
        "format_version": 1,
        "database_sha256": sha256(database),
        "summary": summary,
        "words": records,
        "unreferenced_files": {kind: sorted(files[kind] - used[kind]) for kind in files},
        "case_collisions": {
            kind: [sorted(name for name in files[kind] if name.casefold() == key)
                   for key in sorted({name.casefold() for name in files[kind]})
                   if sum(name.casefold() == key for name in files[kind]) > 1]
            for kind in files
        },
        "decode_validation": str(validation.relative_to(ROOT)) if validation and validation.is_relative_to(ROOT) else None,
    }


def index_from_report(report):
    return {
        "format_version": 1,
        "words": {record["word"]: {field: record[field]["path"] if record[field]["status"] in ("exact", "case_alias", "mapped") else None
                                   for field in ("audio", "image")} for record in report["words"]},
    }


def table_cell(value):
    return str(value).replace("|", "\\|").replace("\n", " ").replace("\r", " ")


def write_checklist(report, path, baseline=None, ledger=None):
    summary = report["summary"]
    lines = ["# Word Resource Checklist", "", "The counts use distinct database words, not lesson rows. Images are optional learning aids; a missing image is not automatically a content defect.", "",
             "| Check | Current |", "| --- | ---: |"]
    lines.extend(f"| {key} | {value} |" for key, value in summary.items())
    if baseline:
        before = json.loads(baseline.read_text(encoding="utf-8"))["summary"]
        lines += ["", "## Audio Completion", "", f"Missing audio before: {before['audio_missing']}. Missing audio now: {summary['audio_missing']}."]
    if ledger and ledger.exists():
        generated = json.loads(ledger.read_text(encoding="utf-8"))["assets"]
        lines += ["", f"AI-generated additions: {len(generated)}. Technical validation is not a substitute for pronunciation listening review."]
        lines += ["", "## Editorial Holds", "", "These existing word-list issues must be reviewed before publishing the synthesized pronunciations. The database has not been rewritten.", "",
                  "| Stored word | Spoken text | Reason |", "| --- | --- | --- |"]
        for asset in generated:
            if asset.get("editorial_review_required"):
                lines.append(f"| {table_cell(asset['word'])} | {table_cell(asset['spoken_text'])} | {table_cell(asset['spoken_text_note'])} |")
    lines += ["", "## Explicit Filename Aliases", "", "| Word | Type | Actual file |", "| --- | --- | --- |"]
    for record in report["words"]:
        for field in ("audio", "image"):
            if record[field]["status"] == "case_alias":
                lines.append(f"| {table_cell(record['word'])} | {field} | {table_cell(record[field]['path'])} |")
    lines += ["", "Image aliases preserve the legacy lookup behavior, but images of case-sensitive meanings (for example May versus may) still need semantic review."]
    for field in ("audio", "image"):
        lines += ["", f"## {field.title()} Follow Up", "", "| Word | Meaning | Book and lesson | Action |", "| --- | --- | --- | --- |"]
        for record in report["words"]:
            if record[field]["status"] not in ("missing", "ambiguous", "invalid"):
                continue
            reference = record["references"][0]
            action = record.get("image_action", record[field]["status"]) if field == "image" else record[field]["status"]
            lines.append(f"| {table_cell(record['word'])} | {table_cell(reference['translation'])} | {reference['book_id']}/{reference['lesson_id']} | {action} |")
    lines += ["", "## Unreferenced Files", "", "Do not delete these automatically; retain them until their origin and use are confirmed."]
    for kind, files in report["unreferenced_files"].items():
        lines.extend(f"- `{kind}/{filename}`" for filename in files)
    validation_complete = bool(report["decode_validation"]) and not summary["audio_invalid"] and not summary["image_invalid"]
    lines += ["", "## Release Checks", "", f"- [{'x' if validation_complete else ' '}] Decode all available audio and image files using native Apple frameworks.",
              "- [ ] Listen to every generated pronunciation, especially abbreviations, proper names, and inflected words.",
              "- [ ] Review image aliases against the database meanings.", "- [ ] Review every new image, context diagram, and labelled meaning card against its word sense.",
              "- [ ] Confirm rights to the pre-existing audio, images, and textbook content separately.",
              "- [ ] Run the native resource decoder and verify the resource index before packaging.", ""]
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text("\n".join(lines), encoding="utf-8")


def write_listening_checklist(report, ledger_path, path):
    if not ledger_path.exists() or path.exists():
        return
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    meanings = {record["word"]: record["references"][0]["translation"] for record in report["words"]}
    lines = ["# Generated Word Audio Listening Review", "",
             "All entries are AI-synthesized British English drafts, not recordings supplied by the textbook publisher. Native decoding and checksum checks do not prove pronunciation accuracy. No entry is marked as human-approved.", "",
             "| Reviewed | Word | Meaning | Spoken text | Seconds | Audio | Editorial hold |",
             "| --- | --- | --- | --- | ---: | --- | --- |"]
    from urllib.parse import quote
    for asset in ledger["assets"]:
        target = quote("../../NCE_ALL/data/words/" + asset["path"], safe="/")
        lines.append(f"| [ ] | {table_cell(asset['word'])} | {table_cell(meanings[asset['word']])} | {table_cell(asset['spoken_text'])} | {asset['duration_seconds']:.2f} | [WAV]({target}) | {'yes' if asset['editorial_review_required'] else ''} |")
    path.write_text("\n".join(lines) + "\n", encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--database", type=Path, default=ROOT / "NCE_ALL/data/NCE.db")
    parser.add_argument("--resources", type=Path, default=ROOT / "NCE_ALL/data/words")
    parser.add_argument("--output", type=Path, default=ROOT / "Docs/word-resources/current.json")
    parser.add_argument("--validation", type=Path)
    parser.add_argument("--checklist", type=Path)
    parser.add_argument("--baseline", type=Path)
    parser.add_argument("--write-index", action="store_true")
    args = parser.parse_args()
    report = audit(args.database, args.resources, args.validation)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    if args.write_index:
        (args.resources / "resource-index.json").write_text(
            json.dumps(index_from_report(report), ensure_ascii=True, indent=2) + "\n", encoding="utf-8"
        )
    if args.checklist:
        write_checklist(report, args.checklist, args.baseline, ROOT / "Docs/word-resources/generated-audio.json")
        write_listening_checklist(report, ROOT / "Docs/word-resources/generated-audio.json", args.checklist.with_name("listening-review.md"))
    print(json.dumps(report["summary"], indent=2))


if __name__ == "__main__":
    main()
