#!/usr/bin/env python3
"""Read-only acoustic screening of every Book 1 recording; never grants listening approval.

Requires an explicitly supplied, pre-existing Allosaurus eng2102 model and a
decoded PCM index. No downloads, synthesis, or source-audio modifications occur.
The recognizer receives audio only, never the expected word or transcription.
"""
import argparse
from collections import Counter, defaultdict
import hashlib
import json
from pathlib import Path
import re
import wave

ROOT = Path(__file__).resolve().parents[1]


def checksum(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def inventory_projection(ipa):
    # Screening projection only. The model cannot certify vowel length, lexical
    # stress, LOT/PALM contrast, or a non-rhotic NURSE vowel. Preserve raw IPA.
    ipa = ipa.replace('eɪ', 'Eɪ').replace('e', 'ɛ').replace('E', 'e')
    ipa = ipa.replace('əʊ', 'oʊ').replace('ɒ', 'ɑ').replace('ɜ', 'ə')
    ipa = ipa.replace('r', 'ɹ').replace('g', 'ɡ')
    return re.sub(r'[\s/ˈˌː.͡]', '', ipa)


def distance(a, b):
    previous = list(range(len(b) + 1))
    for i, ca in enumerate(a, 1):
        current = [i]
        for j, cb in enumerate(b, 1):
            current.append(min(current[-1] + 1, previous[j] + 1,
                               previous[j - 1] + (ca != cb)))
        previous = current
    return previous[-1]


def write_json(path, data):
    path.parent.mkdir(parents=True, exist_ok=True)
    temporary = path.with_suffix('.tmp')
    temporary.write_text(json.dumps(data, ensure_ascii=False, indent=2) + '\n')
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--model-dir', type=Path, required=True)
    parser.add_argument('--decoded-index', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--audio-root', type=Path, default=ROOT,
                        help='Alternate root for checking staged replacements before installation')
    parser.add_argument('--only-words', nargs='+')
    args = parser.parse_args()
    assert args.model_dir.name == 'eng2102'
    model_files = ['model.pt', 'phone.txt', 'pm_config.json', 'am_config.json',
                   'lm_config.json', 'inventory/index.json', 'inventory/stan1293.txt']
    model_hashes = {name: checksum(args.model_dir / name) for name in model_files}
    # Instantiate directly to prevent the package's implicit model download path.
    from argparse import Namespace
    import numpy as np
    import torch
    from allosaurus.app import Recognizer
    from allosaurus.audio import read_audio
    from allosaurus.am.factory import read_am
    from allosaurus.am.utils import move_to_tensor
    from allosaurus.pm.factory import read_pm
    from allosaurus.lm.factory import read_lm

    torch.set_num_threads(4)
    config = Namespace(model='eng2102', device_id=-1, lang='eng', approximate=False, prior=None)
    recognizer = Recognizer(read_pm(args.model_dir, config), read_am(args.model_dir, config),
                            read_lm(args.model_dir, config), config)
    recognizer.am.eval()
    ledger = json.loads((ROOT / 'Docs/phonetics/book1-review.json').read_text())['entries']
    index = {x['path']: x for x in json.loads(args.decoded_index.read_text())}
    contexts = defaultdict(list)
    for row in ledger:
        contexts[row['audio_path']].append(row)
    if args.only_words:
        contexts = {p: rs for p, rs in contexts.items()
                    if any(r['word'] in args.only_words for r in rs)}
    previous = json.loads(args.output.read_text()) if args.output.exists() else {}
    assert not previous or previous['model']['file_sha256'] == model_hashes, 'Model changed'
    reviewed = {x['audio_path']: x for x in previous.get('assets', [])}
    for count, (path, rows) in enumerate(contexts.items(), 1):
        asset = index[path]
        assert checksum(args.audio_root / path) == asset['sha256'], 'Audio changed: ' + path
        assert 'error' not in asset, 'Decode failed: ' + path
        current_pairs = [(f"1|{r['lesson']}|{r['word']}", r['ipa']) for r in rows]
        saved_pairs = [(c['key'], c['expected_ipa'])
                       for c in reviewed.get(path, {}).get('comparisons', [])]
        if (path in reviewed and reviewed[path]['sha256'] == asset['sha256']
                and current_pairs == saved_pairs
                and reviewed[path]['decoded_pcm_sha256'] == checksum(Path(asset['pcm_path']))):
            continue
        pcm_path = Path(asset['pcm_path'])
        with wave.open(str(pcm_path)) as audio:
            assert (audio.getframerate(), audio.getnchannels(), audio.getsampwidth()) == (16000, 1, 2)
            pcm = np.frombuffer(audio.readframes(audio.getnframes()), dtype='<i2').astype(np.float32) / 32768
        np.random.seed(0)
        features = recognizer.pm.compute(read_audio(pcm_path))
        tensors, lengths = move_to_tensor([features[None, ...],
                                          np.array([len(features)], dtype=np.int32)], -1)
        with torch.no_grad():
            logits = recognizer.am(tensors, lengths)[0].numpy()
        raw_phones = recognizer.lm.compute(logits.copy(), 'eng')
        stamped = recognizer.lm.compute(logits.copy(), 'eng', topk=3, timestamp=True)
        observed = re.sub(r'[\s͡]', '', raw_phones)
        comparisons = []
        for row in rows:
            projected = inventory_projection(row['ipa'])
            edit_count = distance(projected, observed)
            comparisons.append({'key': f"1|{row['lesson']}|{row['word']}", 'word': row['word'],
                                'lesson': row['lesson'], 'expected_ipa': row['ipa'],
                                'model_inventory_projection': projected,
                                'symbol_edit_count': edit_count,
                                'screening_result': 'projected_sequence_match' if edit_count == 0
                                                    else 'nonexact_requires_review'})
        active = np.flatnonzero(np.abs(pcm) > 0.005)
        reviewed[path] = {'audio_path': path, 'sha256': asset['sha256'],
                         'decoded_pcm_sha256': checksum(pcm_path),
                         'decoder': asset.get('decode_method', 'macOS afconvert PCM16/16kHz'),
                         'recognized_phones': raw_phones, 'phone_candidates_with_timestamps': stamped,
                         'waveform': {'duration_seconds': len(pcm) / 16000,
                                      'peak': float(np.max(np.abs(pcm))),
                                      'rms': float(np.sqrt(np.mean(pcm * pcm))),
                                      'clipped_samples': int(np.sum(np.abs(pcm) >= 32760 / 32768)),
                                      'active_seconds': float((active[-1] - active[0] + 1) / 16000)
                                                        if len(active) else 0},
                         'comparisons': comparisons, 'listening_approved': False,
                         'stress_audio_checked': False}
        assets = sorted(reviewed.values(), key=lambda x: x['audio_path'])
        results = Counter(c['screening_result'] for x in assets for c in x['comparisons'])
        output = {'format_version': 1, 'book_id': 1, 'date': '2026-10-13',
                  'method': 'Audio-only local acoustic phone recognition plus waveform screening; not a listening certificate or a pronunciation score.',
                  'model': {'name': 'Allosaurus eng2102', 'package_version': '1.0.2',
                            'source': 'https://github.com/xinjli/allosaurus',
                            'download_url': 'https://github.com/xinjli/allosaurus/releases/download/v1.0/eng2102.tar.gz',
                            'file_sha256': model_hashes},
                  'limitations': ['The 38-phone model has no stress or vowel-length output.',
                                  'Its North American phone inventory cannot directly certify all British vowel distinctions.',
                                  'Recognition mismatches can be model errors, valid variants, or audio errors; never automatically replace correct IPA from these predictions.',
                                  'Matching projections do not approve listening, stress, or every phoneme.'],
                  'summary': {'audio_files_processed': len(assets),
                              'contexts_processed': sum(len(x['comparisons']) for x in assets),
                              'screening_counts': dict(results), 'listening_approved': 0},
                  'assets': assets}
        write_json(args.output, output)
        print(f"[{count}/{len(contexts)}] {rows[0]['word']}: {raw_phones}", flush=True)


if __name__ == '__main__':
    main()
