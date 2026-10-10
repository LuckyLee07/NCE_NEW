#!/usr/bin/env python3
"""Download a pinned public build-only model, verify its weights, then convert to int8."""

import argparse
import hashlib
from pathlib import Path
import time

from build_east_asian_localizations import MODEL, REVISION

WEIGHTS_SHA256 = "d907ea45e4e4b9db163382a6674f6218b3c59566fe06d77f4055c208b4e87ed1"


def main():
    from huggingface_hub import snapshot_download
    from ctranslate2.converters import TransformersConverter
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--root", type=Path, required=True, help="Development-only cache, outside NCE_ALL/data")
    args = parser.parse_args()
    if "NCE_ALL/data" in args.root.resolve().as_posix():
        parser.error("The translation model must never be placed in bundled App data")
    for attempt in range(5):
        try:
            source = Path(snapshot_download(MODEL, revision=REVISION, cache_dir=str(args.root / "cache"),
                allow_patterns=["*.json", "sentencepiece.bpe.model", "pytorch_model.bin", "README.md"],
                resume_download=True, use_auth_token=False))
            break
        except Exception:
            if attempt == 4:
                raise
            print("Model download interrupted; resuming the existing partial file.", flush=True)
            time.sleep(2)
    digest = hashlib.sha256()
    with (source / "pytorch_model.bin").open("rb") as stream:
        for block in iter(lambda: stream.read(4 * 1024 * 1024), b""):
            digest.update(block)
    if digest.hexdigest() != WEIGHTS_SHA256:
        raise ValueError("Downloaded weights do not match the pinned model SHA-256")
    converted = args.root / "m2m100-int8"
    if not converted.exists():
        TransformersConverter(str(source)).convert(str(converted), quantization="int8")
    print(f"Source: {source}\nConverted: {converted}")


if __name__ == "__main__":
    main()
