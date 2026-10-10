#!/usr/bin/env python3
"""Verify new pictures, exact meaning mappings, and unchanged original artwork."""

import argparse
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def verify(resources, validation=None):
    docs = ROOT / "Docs/word-resources"
    ledger = json.loads((docs / "generated-images.json").read_text(encoding="utf-8"))
    baseline = json.loads((docs / "baseline.json").read_text(encoding="utf-8"))
    preserved = json.loads((ROOT / "ContentPipeline/word-images/preserved-images.json").read_text(encoding="utf-8"))
    from build_word_images import image_words
    expected = {record["word"] for record in image_words(baseline)}
    assets = ledger["assets"]
    if len(assets) != len(expected) or {asset["word"] for asset in assets} != expected:
        raise ValueError("Picture coverage differs from baseline missing words and recorded semantic repairs")
    if digest(ROOT / "NCE_ALL/data/NCE.db") != preserved["database_sha256"]:
        raise ValueError("The word database changed")
    for path, checksum in preserved["images"].items():
        if digest(resources / path) != checksum:
            raise ValueError(f"Original artwork changed: {path}")
    mapping = json.loads((resources / "generated-image-map.json").read_text(encoding="utf-8"))
    index = json.loads((resources / "resource-index.json").read_text(encoding="utf-8"))
    if mapping != {"format_version": 1, "images": {asset["word"]: asset["path"] for asset in assets}}:
        raise ValueError("Generated map is out of sync")
    checks = {record["file"]: record for record in json.loads(validation.read_text(encoding="utf-8"))["jpg"]} if validation else {}
    total = 0
    case_safe = set()
    for asset in assets:
        path = asset["path"]
        parts = path.split("/")
        if len(parts) != 2 or parts[0] != "jpg" or not parts[1].endswith(".jpg") or "\\" in path or parts[1] in {".", ".."}:
            raise ValueError(f"Unsafe image path: {path}")
        if path.casefold() in case_safe:
            raise ValueError(f"Generated case collision: {path}")
        case_safe.add(path.casefold())
        image = resources / path
        data = image.read_bytes()
        if not data.startswith(b"\xff\xd8") or len(data) > 8192 or len(data) != asset["bytes"] or digest(image) != asset["sha256"]:
            raise ValueError(f"Invalid bytes, size, or checksum: {path}")
        if asset["width"] != 128 or asset["height"] != 128 or index["words"][asset["word"]]["image"] != path:
            raise ValueError(f"Invalid dimensions or lookup: {path}")
        if validation:
            check = checks.get(parts[1], {})
            if not check.get("valid") or not check.get("nonblank") or check.get("width") != 128 or check.get("height") != 128:
                raise ValueError(f"Native pixel/decode validation failed: {path}")
        if asset["kind"] == "meaning_card" and asset["source"] != "project-native-diagram-or-text":
            raise ValueError("Meaning cards must not masquerade as AI illustrations")
        total += len(data)
    for source in json.loads((ROOT / "ContentPipeline/word-images/sources.json").read_text(encoding="utf-8"))["icons"]:
        if digest(ROOT / "ContentPipeline/word-images/twemoji" / (source["icon"] + ".png")) != source["sha256"]:
            raise ValueError(f"Icon source changed: {source['icon']}")
    from split_word_image_atlas import validate_manifest
    atlas_cells = {}
    for manifest_path in (ROOT / "ContentPipeline/word-images").glob("atlas-*.json"):
        atlas = json.loads(manifest_path.read_text(encoding="utf-8"))
        validate_manifest(atlas)
        if digest(manifest_path.parent / atlas["source"]) != atlas["source_sha256"]:
            raise ValueError(f"Atlas source changed: {atlas['id']}")
        for cell in atlas["cells"]:
            if digest(manifest_path.parent / cell["source"]) != cell["sha256"] or cell["width"] != 128 or cell["height"] != 128:
                raise ValueError(f"Atlas cell changed: {cell['source']}")
            atlas_cells[cell["source"]] = [cell["word"], *cell.get("also_words", [])]
    for asset in assets:
        if asset.get("generated_source") in atlas_cells and asset["word"] not in atlas_cells[asset["generated_source"]]:
            raise ValueError(f"Atlas cell assigned to the wrong word: {asset['word']}")
    credit = resources / "licenses/attribution.txt"
    if not credit.exists() or "CC BY 4.0" not in credit.read_text(encoding="utf-8") or not (credit.parent / "Twemoji-CC-BY-4.0.txt").exists():
        raise ValueError("Bundled attribution/license is missing")
    print(f"Verified {len(assets)} new 128x128 JPGs, {total / 1048576:.2f} MiB; {len(preserved['images'])} original images unchanged.")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resources", type=Path, default=ROOT / "NCE_ALL/data/words")
    parser.add_argument("--validation", type=Path)
    args = parser.parse_args()
    verify(args.resources, args.validation)


if __name__ == "__main__":
    main()
