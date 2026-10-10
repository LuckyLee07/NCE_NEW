#!/usr/bin/env python3
"""Verify the generated WAV ledger without installing any TTS dependencies."""

import argparse
import hashlib
import json
from pathlib import Path
import wave

ROOT = Path(__file__).resolve().parents[1]


def verify(resources, ledger_path, baseline_path):
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    baseline = json.loads(baseline_path.read_text(encoding="utf-8"))
    required = {record["word"] for record in baseline["words"] if record["audio"]["status"] == "missing"}
    records = ledger["assets"]
    if len(records) != len(required) or {record["word"] for record in records} != required:
        raise ValueError("The generation ledger does not cover every baseline missing word exactly once")
    total_bytes = 0
    for record in records:
        relative = record["path"]
        if relative != f"wav/{record['word']}.wav" or any(character in record["word"] for character in ("/", "\\", "\x00")):
            raise ValueError(f"Invalid ledger path: {relative}")
        path = resources / relative
        data = path.read_bytes()
        if hashlib.sha256(data).hexdigest() != record["sha256"]:
            raise ValueError(f"Generated file checksum mismatch: {relative}")
        with wave.open(str(path)) as audio:
            if audio.getnchannels() != 1 or audio.getsampwidth() != 2 or audio.getframerate() != 24000:
                raise ValueError(f"Unexpected WAV format: {relative}")
            duration = audio.getnframes() / audio.getframerate()
            if abs(duration - record["duration_seconds"]) > 0.001 or not 0.15 <= duration <= 16:
                raise ValueError(f"Unexpected WAV duration: {relative}")
        total_bytes += len(data)
    print(f"Verified {len(records)} generated mono PCM WAV files ({total_bytes / 1024 / 1024:.2f} MiB); listening review remains separate")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--resources", type=Path, default=ROOT / "NCE_ALL/data/words")
    parser.add_argument("--ledger", type=Path, default=ROOT / "Docs/word-resources/generated-audio.json")
    parser.add_argument("--baseline", type=Path, default=ROOT / "Docs/word-resources/baseline.json")
    args = parser.parse_args()
    verify(args.resources, args.ledger, args.baseline)


if __name__ == "__main__":
    main()
