#!/usr/bin/env python3
"""Split a user-requested four-word atlas into deterministic, recorded icon sources."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
PIPELINE = ROOT / "ContentPipeline/word-images"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def validate_manifest(manifest):
    if manifest.get("format_version") != 1 or manifest.get("grid") != [2, 2]:
        raise ValueError("Expected a format-1 2x2 atlas")
    if not re.fullmatch(r"[a-z0-9][a-z0-9-]{0,60}", manifest.get("id", "")):
        raise ValueError("Unsafe atlas ID")
    if manifest.get("source") != manifest["id"] + ".png":
        raise ValueError("Unexpected atlas source filename")
    cells = manifest.get("cells", [])
    if len(cells) != 4 or [cell.get("index") for cell in cells] != [0, 1, 2, 3] or len({cell.get("word") for cell in cells}) != 4:
        raise ValueError("Exactly four distinct words are required in row-major order")
    assigned_words = {cell["word"] for cell in cells}
    for cell in cells:
        if not isinstance(cell.get("word"), str) or not cell["word"] or cell.get("source") != f"{manifest['id']}-{cell['index']}.png":
            raise ValueError("Unsafe or missing cell word/source")
        aliases = cell.get("also_words", [])
        if not isinstance(aliases, list):
            raise ValueError("Cell aliases must be an explicit list")
        for word in aliases:
            if not isinstance(word, str) or not word or any(character in word for character in ("/", "\\", "\x00")) or word in assigned_words:
                raise ValueError("Unsafe or duplicate cell alias")
            assigned_words.add(word)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--manifest", type=Path, required=True)
    args = parser.parse_args()
    manifest = json.loads(args.manifest.read_text(encoding="utf-8"))
    validate_manifest(manifest)
    source = PIPELINE / manifest["source"]
    if digest(source) != manifest["source_sha256"]:
        raise ValueError("Atlas source changed; review it before splitting")
    for cell in manifest["cells"]:
        path = PIPELINE / cell["source"]
        if path.exists() and digest(path) != cell.get("sha256"):
            raise ValueError(f"Refusing to replace an unrecorded or modified cell: {path}")
    with tempfile.TemporaryDirectory(prefix="nce-word-atlas-") as temporary:
        temporary = Path(temporary)
        executable = temporary / "splitter"
        subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "Foundation", "-framework", "ImageIO", "-framework", "CoreGraphics",
                        str(ROOT / "Tools/split_word_image_atlas.m"), "-o", str(executable)], check=True)
        prefix = temporary / manifest["id"]
        subprocess.run([str(executable), str(source), str(prefix)], check=True)
        for cell in manifest["cells"]:
            data = (temporary / cell["source"]).read_bytes()
            checksum = hashlib.sha256(data).hexdigest()
            path = PIPELINE / cell["source"]
            if path.exists() and digest(path) != checksum:
                raise ValueError("Same atlas produced different cell bytes; review the toolchain before replacing")
            if not path.exists():
                with path.open("xb") as output:
                    output.write(data)
            cell.update({"sha256": checksum, "width": 128, "height": 128})
    args.manifest.write_text(json.dumps(manifest, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")


if __name__ == "__main__":
    main()
