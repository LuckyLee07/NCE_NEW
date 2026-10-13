#!/usr/bin/env python3
"""Build the explicitly selected pilot; no automatic guesses or bulk publishing."""
import csv, hashlib, json, re, shutil, sqlite3
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
SOURCE = ROOT / 'ContentPipeline/phonetics'
OUT = ROOT / 'NCE_ALL/data/words'

def signature(text):
    return re.sub(r'[\s/ˈˌ]', '', text.translate(str.maketrans({'ɹ':'r','ɛ':'e','ɐ':'ʌ','ɡ':'g'})))

def build():
    vendor = SOURCE / 'vendor/Britfone'
    provenance = json.loads((vendor / 'provenance.json').read_text())
    for name, info in provenance['files'].items():
        assert hashlib.sha256((vendor/name).read_bytes()).hexdigest() == info['sha256'], name
    index = {}
    for key, phonemes in csv.reader((vendor/'britfone.main.3.0.1.csv').open()):
        word = re.sub(r'\(\d+\)$','',key).lower().replace('_',' ')
        index.setdefault(word, []).append({'key':key,'phonemes':phonemes.strip()})
    db = sqlite3.connect(f'file:{ROOT}/NCE_ALL/data/NCE.db?mode=ro',uri=True)
    audio_index = json.loads((OUT/'resource-index.json').read_text())['words']
    records = {}; ledger = []
    for row in csv.DictReader((SOURCE/'pilot.tsv').open(), delimiter='\t'):
        book = int(row['book']); word = row['word']; ipa = row['ipa']
        matches = [v for v in index[word.lower()] if signature(v['phonemes']) == signature(ipa)]
        assert matches, (word, ipa, index.get(word.lower()))
        contexts = db.execute('SELECT id,lesson_id,word_translation FROM words WHERE book_id=? AND word_name=? ORDER BY lesson_id,order_id',(book,word)).fetchall()
        assert contexts, word
        # One reviewed curriculum context per pilot word; no blind homograph sharing.
        word_id, lesson, meaning = contexts[0]
        key = f'{book}|{lesson}|{word}'
        assert key not in records
        records[key] = {'ipa':f'/{ipa}/','accent':'en-GB','status':'source_checked','source_id':'Britfone-3.0.1','source_key':matches[0]['key']}
        audio = audio_index.get(word, {}).get('audio')
        assert audio and (OUT/audio).is_file(), (word, 'missing audio for later listening review')
        ledger.append(dict(row,book=book,lesson=lesson,word_id=word_id,meaning=meaning,source=matches[0],reviewer='assistant',text_review='source_checked',audio_alignment='pending_listening',audio_path=str((OUT/audio).relative_to(ROOT))))
    assert len(records)==100
    assert all(sum(r['book']==b for r in ledger)==25 for b in range(1,5))
    result={'format_version':1,'scope':'P1 pilot: 25 selected contexts per book','records':records,'source':provenance}
    OUT.mkdir(parents=True,exist_ok=True)
    (OUT/'phonetics-pilot.json').write_text(json.dumps(result,ensure_ascii=False,indent=2)+'\n')
    shutil.copyfile(vendor/'LICENSE.txt',OUT/'Britfone-LICENSE.txt')
    docs=ROOT/'Docs/phonetics';docs.mkdir(exist_ok=True)
    (docs/'pilot-review.json').write_text(json.dumps({'entries':ledger,'audio_note':'Dictionary IPA is source-checked; existing recordings are unchanged and not yet certified as matching every IPA.'},ensure_ascii=False,indent=2)+'\n')
    print('Built 100 source-checked IPA records (25 per book); retained source license.')
if __name__=='__main__': build()
