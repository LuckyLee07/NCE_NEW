#!/usr/bin/env python3
"""Build explicitly annotated volume data; never infer missing pronunciations."""
import csv
import hashlib
import json
import re
import sqlite3
from collections import Counter

from build_phonetics_pilot import ROOT, SOURCE, OUT, signature


def build_book1():
    vendor = SOURCE / 'vendor/Britfone'
    provenance = json.loads((vendor / 'provenance.json').read_text())
    for name, info in provenance['files'].items():
        assert hashlib.sha256((vendor / name).read_bytes()).hexdigest() == info['sha256'], name
    with (vendor / 'britfone.main.3.0.1.csv').open() as stream:
        source = dict(csv.reader(stream))
    supplement = json.loads((SOURCE / 'book1-supplement.json').read_text())['entries']
    with (SOURCE / 'book1.tsv').open() as stream:
        rows = list(csv.DictReader(stream, delimiter='\t'))
    with sqlite3.connect(f'file:{ROOT}/NCE_ALL/data/NCE.db?mode=ro', uri=True) as db:
        contexts = db.execute('SELECT id,lesson_id,word_name,word_translation FROM words '
                              'WHERE book_id=1 AND lesson_id>0 ORDER BY lesson_id,order_id').fetchall()
        excluded = db.execute('SELECT id,lesson_id,word_name FROM words WHERE book_id=1 '
                              'AND (lesson_id IS NULL OR lesson_id<=0)').fetchall()
    expected = {(lesson, word): (word_id, meaning) for word_id, lesson, word, meaning in contexts}
    assert len(expected) == len(contexts), 'Duplicate curriculum contexts'
    keys = [(int(row['lesson']), row['word']) for row in rows]
    assert len(keys) == len(set(keys)), 'Duplicate annotation contexts'
    assert set(keys) == set(expected), {'missing': sorted(set(expected) - set(keys)),
                                       'unexpected': sorted(set(keys) - set(expected))}
    assert len(rows) == 624, 'Book 1 curriculum changed; review scope before rebuilding'
    audio_index = json.loads((OUT / 'resource-index.json').read_text())['words']
    records, ledger = {}, []
    used_supplements = set()
    for row in rows:
        lesson, word, ipa, source_key = int(row['lesson']), row['word'], row['ipa'], row['source_key']
        assert ipa and ipa == ipa.strip() and '/' not in ipa, (word, 'Invalid IPA')
        assert not any(ord(c) < 32 for c in ipa), (word, 'Control character')
        status = 'source_checked'
        if source_key.startswith('supplement:'):
            assert source_key == f'supplement:{word}', (word, 'Wrong supplement key')
            evidence = supplement[word]
            used_supplements.add(word)
            assert ipa == evidence['ipa'], (word, 'Supplement transcription changed')
            assert evidence['reference_url'].startswith('https://') and evidence['note'], word
            method = evidence['method']
            if method == 'editorial_phrase':
                components = [source[key] for key in evidence['component_source_keys']]
                assert signature(ipa) == signature(' '.join(components)), (word, 'Component mismatch')
                status = 'editorial_checked'
            elif method == 'reviewed_inflection':
                assert word == 'sales reps' and evidence['suffix'] == 's', word
                assert ipa == evidence['base_ipa'] + evidence['suffix'], word
            else:
                assert method == 'dictionary_entry' and evidence['reference_accent'] == 'UK', word
            source_id = 'Book1-editorial' if method == 'editorial_phrase' else 'Book1-dictionary-checks'
        else:
            allowed_word = {'Mr.': 'mister', 'Mrs.': 'missis'}.get(word, word.lower())
            assert re.sub(r'\(\d+\)$', '', source_key).lower().replace('_', ' ') == allowed_word, word
            assert signature(ipa) == signature(source[source_key]), (word, 'Source phoneme mismatch')
            evidence = {'method': 'britfone_entry', 'key': source_key, 'phonemes': source[source_key].strip()}
            source_id = 'Britfone-3.0.1'
        word_id, meaning = expected[(lesson, word)]
        audio = audio_index.get(word, {}).get('audio')
        audio_exists = bool(audio and (OUT / audio).is_file())
        records[f'1|{lesson}|{word}'] = {'ipa': f'/{ipa}/', 'accent': 'en-GB', 'status': status,
                                       'source_id': source_id, 'source_key': source_key}
        ledger.append(dict(row, book=1, lesson=lesson, word_id=word_id, meaning=meaning,
                           reviewer='assistant', text_review=status, source=evidence,
                           audio_alignment='pending_listening' if audio_exists else 'missing_audio',
                           audio_path=str((OUT / audio).relative_to(ROOT)) if audio_exists else None))
    assert used_supplements == set(supplement), 'Unused supplemental evidence'
    result = {'format_version': 1, 'book_id': 1, 'scope': 'All 624 lesson vocabulary contexts in book 1',
              'release_status': 'local_annotation_review', 'records': records, 'source': provenance}
    report = {'book_id': 1, 'date': '2026-10-13', 'curriculum_contexts': len(expected),
              'annotated_contexts': len(records), 'lesson_count': len({r['lesson'] for r in ledger}),
              'missing_contexts': [], 'text_review_counts': dict(Counter(r['text_review'] for r in ledger)),
              'source_method_counts': dict(Counter(r['source']['method'] for r in ledger)),
              'audio_review_counts': dict(Counter(r['audio_alignment'] for r in ledger)),
              'excluded_non_lesson_rows': [dict(zip(['word_id', 'lesson', 'word'], r)) for r in excluded],
              'release_status': 'local_annotation_review',
              'limitations': ['Audio alignment and teacher review are pending.',
                             'Editorial phrase stress is explicitly authored, not dictionary-certified.',
                             'Coverage refers to lesson vocabulary, not every token in lesson prose.'],
              'per_lesson': dict(sorted(Counter(r['lesson'] for r in ledger).items()))}
    # All checks above finish before any generated output is replaced.
    docs = ROOT / 'Docs/phonetics'
    docs.mkdir(parents=True, exist_ok=True)
    for path, data in [(OUT / 'phonetics-book1.json', result),
                       (docs / 'book1-review.json', {'summary': report, 'entries': ledger}),
                       (docs / 'book1-validation.json', report)]:
        path.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    print(f"Built book 1: {len(records)} contexts; {report['text_review_counts']}; "
          f"audio: {report['audio_review_counts']}")


if __name__ == '__main__':
    build_book1()
