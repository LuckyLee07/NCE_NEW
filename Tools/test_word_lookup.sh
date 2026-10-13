#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEST_DIR="$(mktemp -d "${TMPDIR:-/tmp}/nce-word-lookup.XXXXXX")"
trap 'rm -rf "$TEST_DIR"' EXIT
cd "$ROOT"
xcrun clang -fobjc-arc -framework Foundation NCE_ALL/Utility/NCEWordLookup.m Tools/tests/word_lookup_test.m -o "$TEST_DIR/check"
"$TEST_DIR/check"
