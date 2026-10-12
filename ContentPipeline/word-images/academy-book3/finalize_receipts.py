"""Persist manually reviewed built-in ImageGen atlases and export lossless tiles."""
import hashlib, json, shutil, subprocess, sys
from pathlib import Path
ROOT = Path(__file__).resolve().parents[3]
OUT = Path(__file__).resolve().parent
for identifier in sys.argv[1:]:
    assert identifier.startswith('academy-b3-') and '/' not in identifier
    path = OUT/'jobs'/f'{identifier}.json'
    receipt = json.loads(path.read_text())
    assert receipt['review_status'] == 'assistant_visual_reviewed'
    source = Path(receipt['original_generated'])
    destination = OUT/'atlases'/f'{identifier}.png'
    if source.resolve() != destination.resolve():
        if destination.exists():
            assert destination.read_bytes() == source.read_bytes(), 'Atlas changed'
        else:
            shutil.copyfile(source, destination)
    receipt['original_generated'] = str(destination.resolve())
    receipt['source_sha256'] = hashlib.sha256(destination.read_bytes()).hexdigest()
    path.write_text(json.dumps(receipt, ensure_ascii=False, indent=2)+'\n')
    subprocess.run(['/tmp/nce-academy-b3-export-atlas', str(path), str(ROOT/'NCE_ALL/data/words/png')], check=True)
