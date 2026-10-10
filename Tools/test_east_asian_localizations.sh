#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-east-asian-tests.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"
RESOURCES="${1:-$ROOT/NCE_ALL}"
PYTHONDONTWRITEBYTECODE=1 python3 Tools/build_east_asian_localizations.py --verify
PYTHONDONTWRITEBYTECODE=1 python3 -m unittest discover -s Tools/tests -p 'test_east_asian_localizations.py'
ln -s "$RESOURCES/data" "$TEMP/data"
for LANGUAGE in zh-Hans zh-Hant ja ko; do
    ln -s "$RESOURCES/$LANGUAGE.lproj" "$TEMP/$LANGUAGE.lproj"
    plutil -lint "$RESOURCES/$LANGUAGE.lproj/Localizable.strings" "$RESOURCES/$LANGUAGE.lproj/InfoPlist.strings"
done
xcrun clang -fobjc-arc -framework Foundation NCE_ALL/Utility/NCELocalization.m \
    NCE_ALL/Utility/NCEWordResourceStore.m Tools/tests/east_asian_localization_test.m -o "$TEMP/localization-test"
"$TEMP/localization-test" "$RESOURCES"
