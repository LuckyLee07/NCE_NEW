#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-phonetics.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"
python3 Tools/build_phonetics_pilot.py
python3 Tools/build_phonetics_book.py
xcrun clang -fobjc-arc -framework Foundation NCE_ALL/Utility/NCELocalization.m NCE_ALL/Utility/NCEWordResourceStore.m Tools/tests/phonetics_store_test.m -o "$TEMP/store-test"
"$TEMP/store-test" "$ROOT/NCE_ALL/data/words"
