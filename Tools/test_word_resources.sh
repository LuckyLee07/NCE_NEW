#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-word-tests.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"
RESOURCES="${1:-$ROOT/NCE_ALL/data/words}"
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_audit_word_resources.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_build_word_images.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_word_image_atlas.py'
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_review_word_audio.py'
xcrun clang -fobjc-arc -framework Foundation -framework AVFoundation -framework ImageIO -framework CoreGraphics \
    Tools/tests/word_resource_decoder.m -o "$TEMP/decoder"
"$TEMP/decoder" "$RESOURCES" "$TEMP/decode.json"
python3 Tools/audit_word_resources.py --resources "$RESOURCES" --validation "$TEMP/decode.json" --output "$TEMP/audit.json"
xcrun clang -fobjc-arc -framework Foundation NCE_ALL/Utility/NCELocalization.m NCE_ALL/Utility/NCEWordResourceStore.m \
    Tools/tests/word_resource_store_test.m -o "$TEMP/store-test"
"$TEMP/store-test" "$RESOURCES" "$TEMP/audit.json"
python3 Tools/verify_generated_word_audio.py --resources "$RESOURCES"
python3 Tools/verify_generated_word_images.py --resources "$RESOURCES" --validation "$TEMP/decode.json"
