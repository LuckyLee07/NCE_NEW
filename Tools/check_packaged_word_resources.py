#!/usr/bin/env python3
"""Compare actual App word resources with source, excluding only macOS metadata."""

import argparse
from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory(directory):
    return {path.relative_to(directory).as_posix(): digest(path)
            for path in directory.rglob("*") if path.is_file() and path.name != ".DS_Store"}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app", type=Path, required=True)
    parser.add_argument("--previous-app", type=Path)
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    source = ROOT / "NCE_ALL/data/words"
    bundled = args.app / "data/words"
    current = inventory(source)
    packaged = inventory(bundled)
    if current != packaged or not packaged:
        raise ValueError("Packaged word file lists or SHA-256 hashes differ from source")
    if list(bundled.rglob("*.png")) or list(bundled.rglob(".DS_Store")):
        raise ValueError("Production source artwork or macOS metadata leaked into the App")
    if digest(args.app / "data/NCE.db") != digest(ROOT / "NCE_ALL/data/NCE.db"):
        raise ValueError("Packaged database differs from source")
    preserved = json.loads((ROOT / "ContentPipeline/word-images/preserved-images.json").read_text())
    if any(current[path] != checksum for path, checksum in preserved["images"].items()):
        raise ValueError("Original picture changed")
    original_audio = None
    if args.previous_app:
        baseline = json.loads((ROOT / "Docs/word-resources/baseline.json").read_text())
        paths = {row["audio"]["path"] for row in baseline["words"] if row["audio"]["path"]}
        paths.update("wav/" + name for name in baseline["unreferenced_files"]["wav"])
        previous = args.previous_app / "data/words"
        if any(digest(previous / path) != current[path] for path in paths):
            raise ValueError("An original WAV differs from the earlier independently built App")
        original_audio = {"count": len(paths), "reference_app": str(args.previous_app), "differences": 0}
    result = {"format_version": 1, "verified_at_utc": datetime.now(timezone.utc).isoformat(),
              "app": str(args.app), "identical_word_resource_files": len(packaged), "differences": 0,
              "packaged_database_sha256": digest(args.app / "data/NCE.db"),
              "original_images_unchanged": len(preserved["images"]), "original_audio_comparison": original_audio,
              "excluded_source_metadata": sorted(path.relative_to(source).as_posix() for path in source.rglob(".DS_Store")),
              "word_source_pngs_in_app": 0,
              "content_acceptance": "Technical packaging check only, not human semantic/listening or physical-device UI approval"}
    args.output.write_text(json.dumps(result, ensure_ascii=True, indent=2) + "\n")
    print(json.dumps(result, indent=2))


if __name__ == "__main__":
    main()
