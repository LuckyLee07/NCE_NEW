#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-localization-tests.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"
RESOURCES="${1:-$ROOT/NCE_ALL}"
PYTHONDONTWRITEBYTECODE=1 python3 Tools/build_chinese_localizations.py --verify
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_chinese_localizations.py'
ln -s "$RESOURCES/data" "$TEMP/data"
ln -s "$RESOURCES/zh-Hans.lproj" "$TEMP/zh-Hans.lproj"
ln -s "$RESOURCES/zh-Hant.lproj" "$TEMP/zh-Hant.lproj"
xcrun clang -fobjc-arc -framework Foundation NCE_ALL/Utility/NCELocalization.m \
    NCE_ALL/Utility/NCEWordResourceStore.m Tools/tests/chinese_localization_test.m -o "$TEMP/localization-test"
"$TEMP/localization-test" "$RESOURCES"
