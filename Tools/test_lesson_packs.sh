#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-pack-tests.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"

PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_*.py'
python3 Tools/build_lesson_packs.py --verify
python3 Tools/tests/make_reader_fixtures.py "$TEMP/fixtures"
xcrun clang -DNOUNCRYPT -c NCE_ALL/ThirdParty/minizip/unzip.c -o "$TEMP/unzip.o"
xcrun clang -c NCE_ALL/ThirdParty/minizip/ioapi.c -o "$TEMP/ioapi.o"
xcrun clang -fobjc-arc -framework Foundation -framework AVFoundation -lz \
    NCE_ALL/Utility/NCELessonResourceStore.m Tools/tests/lesson_resource_store_test.m \
    "$TEMP/unzip.o" "$TEMP/ioapi.o" -o "$TEMP/reader-test"
"$TEMP/reader-test" "${1:-$ROOT/NCE_ALL/data/lesson-packs}" "$TEMP/fixtures"
