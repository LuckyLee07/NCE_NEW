#!/bin/bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TEMP="$(mktemp -d "${TMPDIR:-/tmp}/nce-academy-word-tests.XXXXXX")"
trap 'rm -rf "$TEMP"' EXIT
cd "$ROOT"
RESOURCES="${1:-$ROOT/NCE_ALL/data/words}"
BOOK_ID="${2:-1}"
# Compare the map's actual keys to the database, including when validating an App bundle.
DATABASE="$(dirname "$RESOURCES")/NCE.db"
if [ ! -f "$DATABASE" ]; then DATABASE="$ROOT/NCE_ALL/data/NCE.db"; fi
python3 - "$RESOURCES" "$BOOK_ID" "$DATABASE" <<'PY'
import json
from pathlib import Path
import sqlite3
import sys
resources=Path(sys.argv[1])
book=int(sys.argv[2])
if book not in range(1,5):
    raise SystemExit('Expected Book 1–4')
name='academy-image-map.json' if book==1 else f'academy-book{book}-image-map.json'
mapping=json.loads((resources/name).read_text())
with sqlite3.connect(Path(sys.argv[3]).resolve().as_uri()+'?mode=ro',uri=True) as database:
    expected={row[0] for row in database.execute('SELECT DISTINCT word_name FROM words WHERE book_id=?',(book,))}
actual=set(mapping['images'])|set(mapping['hints'])
if actual != expected:
    raise SystemExit(f'Book {book} coverage differs from database: missing={sorted(expected-actual)}, extra={sorted(actual-expected)}')
PY
xcrun clang -fobjc-arc -framework Foundation -framework ImageIO -framework CoreGraphics \
  NCE_ALL/Utility/NCELocalization.m NCE_ALL/Utility/NCEWordResourceStore.m \
  Tools/tests/academy_word_resource_store_test.m -o "$TEMP/check"
"$TEMP/check" "$RESOURCES" "$BOOK_ID"
