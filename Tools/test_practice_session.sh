#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-practice-tests.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"
xcrun clang -fobjc-arc -framework Foundation NCE_ALL/Utility/NCEPracticeSession.m Tools/tests/practice_session_test.m -o "$TEMP/practice-tests"
"$TEMP/practice-tests"
