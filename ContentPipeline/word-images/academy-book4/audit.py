"""Verify complete Book 4 provenance and preservation of earlier resources."""
import hashlib
import json
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
def read(path):
    return json.loads(path.read_text())
def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()

plan = read(OUT/'plan.json')
receipts = list((OUT/'jobs').glob('academy-b4-*.json'))
active = Counter()
for path in receipts:
    receipt = read(path)
    assert receipt['review_status'] == 'assistant_visual_reviewed', path
    assert receipt['mode'] == 'built-in image_gen', path
    atlas = Path(receipt['original_generated'])
    assert atlas.is_relative_to(OUT/'atlases'), path
    assert digest(atlas) == receipt['source_sha256'], path
    for cell in receipt['cells']:
        if not cell.get('superseded_by'):
            active[cell['word']] += 1
expected = {w['word'] for w in plan['words'] if w['kind'] == 'ai_illustration'}
assert set(active) == expected
assert all(count == 1 for count in active.values())
preserved = read(OUT/'preserved-resources.json')
for name, sha in preserved['book1_book2_book3_resources'].items():
    assert digest(ROOT/'NCE_ALL/data/words'/name) == sha, name
assert digest(ROOT/'NCE_ALL/data/NCE.db') == preserved['database_sha256']
report = read(ROOT/'Docs/word-resources/academy-book4-report.json')
assert report['summary']['covered_words'] == plan['word_count'] == 782
assert not report['summary']['missing_words']
for word in report['words']:
    if 'path' in word:
        path = ROOT/'NCE_ALL/data/words'/word['path']
        assert digest(path) == word['sha256'], path
        assert path.stat().st_size == word['bytes'] <= 200000, path
result = {
    'status':'passed', 'reviewed_atlas_receipts':len(receipts),
    'active_ai_words':len(active), 'all_ai_words_have_exactly_one_active_reviewed_receipt':True,
    'all_atlas_hashes_match':True, 'all_referenced_png_hashes_and_budgets_valid':True,
    'preserved_book1_book2_book3_resources':len(preserved['book1_book2_book3_resources']),
    'database_unchanged':True,
}
(OUT/'final-resource-audit.json').write_text(json.dumps(result,indent=2)+'\n')
print(json.dumps(result,indent=2))
