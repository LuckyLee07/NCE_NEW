#!/usr/bin/env python3
"""Prepare Book 4 sense-reviewed 2×2 illustration jobs; preserve completed receipts."""
import argparse, copy, hashlib, importlib.util, json, sqlite3
from collections import Counter
from pathlib import Path
ROOT=Path(__file__).resolve().parents[3]
OUT=Path(__file__).resolve().parent
spec=importlib.util.spec_from_file_location('book4_semantic_rules',OUT/'semantic-rules.py')
rules=importlib.util.module_from_spec(spec);spec.loader.exec_module(rules)
STYLE='Use case: scientific-educational. Create ONE SQUARE 2x2 atlas with four equal square cells for an adult vocabulary app. Attached image is STYLE REFERENCE ONLY: restrained ink-and-watercolor educational illustrations, clear dark blue-charcoal outlines, pale blue wash, small warm natural color accents. Pure WHITE opaque background. Central 75% of each quadrant contains its subject with generous margins. Nothing crosses midlines. Leave horizontal 45–55% and vertical 47–53% center bands EMPTY WHITE. Natural human anatomy, recognizable objects, clear 320px silhouettes, restrained detail, no elaborate environment. NO captions, labels, writing, borders, grid lines, watermarks or logos. Only symbols or numerals explicitly requested in a cell are allowed. Meanings are guidance; never write them. Row-major fixed order. FOUR CELLS:\n'
POSITIONS=['TOP LEFT','TOP RIGHT','BOTTOM LEFT','BOTTOM RIGHT']
def read(path):return json.loads(path.read_text())
def write(path,data):path.write_text(json.dumps(data,ensure_ascii=False,indent=2)+'\n')
def extract_words():
 words={}
 overrides=read(ROOT/'NCE_ALL/data/words/editorial-overrides.json')['overrides']
 with sqlite3.connect((ROOT/'NCE_ALL/data/NCE.db').resolve().as_uri()+'?mode=ro',uri=True) as db:
  for name,meaning,lesson in db.execute('SELECT word_name,word_translation,lesson_id FROM words WHERE book_id=4 ORDER BY lesson_id,order_id'):
   if name not in words:words[name]={'word':name,'meaning':overrides.get(name,{}).get('translation',meaning or ''), 'lessons':[]}
   if lesson not in words[name]['lessons']:words[name]['lessons'].append(lesson)
 return list(words.values())
def scenes():
 merged={}
 for name in ['scenes.json']:
  path=OUT/name
  if path.exists():
   d=read(path)
   if 'words' in d:d=d['words']
   for key,value in d.items():
    if isinstance(value,str):value={'scene':value}
    merged[key]=value
 return merged
def resolved_source(book,key):
 plan=read(ROOT/f'ContentPipeline/word-images/academy-book{book}/plan.json')
 words={w['word']:w for w in plan['words']};source=words[key]
 seen=set()
 while source['kind']=='shared_illustration':
  if source['word'] in seen:raise ValueError('Source alias cycle')
  seen.add(source['word']);source=words[source['same_as']]
 if source['kind']=='shared_book_illustration':return resolved_source(source['source_book_id'],source['source_word'])
 if source['kind']=='native_hint':raise ValueError(f'Cannot reuse a hint: {book}/{key}')
 return source

def main():
 parser=argparse.ArgumentParser(description=__doc__)
 parser.add_argument('--partial',action='store_true',help='Write only contiguous stable prompt jobs while scene authoring continues')
 args=parser.parse_args();words=extract_words();write(OUT/'source-words.json',words)
 names={w['word'] for w in words};scene_specs=scenes()
 extras=set(scene_specs)-names
 if extras:raise ValueError(f'Unknown scene keys: {extras}')
 prepared=[];missing=[]
 for base in words:
  w=copy.deepcopy(base);key=w['word'];w['filename']='academy-b4-'+hashlib.sha256(key.encode()).hexdigest()[:16]+'.png'
  if key in rules.HINTS:w.update(kind='native_hint',hint=rules.HINTS[key])
  elif key in rules.REUSE:
   book,source_word=rules.REUSE[key];source=resolved_source(book,source_word)
   w.update(kind='shared_book_illustration',source_book_id=book,source_word=source_word,source_filename=source['filename'],review_reason='Explicit review of the curriculum meaning against the existing source scene; no spelling-based inference.')
   if source.get('presentation'):w['presentation']=source['presentation']
   if source_word==key and source.get('caption'):w['caption']=source['caption']
  elif key in rules.DIAGRAMS:w.update(kind='native_diagram',diagram=rules.DIAGRAMS[key],presentation='diagram')
  elif key in scene_specs:
   w.update(kind='ai_illustration',**scene_specs[key]);w['kind']='ai_illustration'
  else:
   w.update(kind='ai_illustration');missing.append(key)
  if key in rules.CAPTIONS:w['caption']=rules.CAPTIONS[key]
  if w['kind']=='ai_illustration' and w.get('caption'):w['presentation']='scene'
  prepared.append(w)
 pics=[w for w in prepared if w['kind']=='ai_illustration'];jobs=[];prompt_jobs=[]
 for i in range(0,len(pics),4):
  batch=pics[i:i+4]
  if any(not w.get('scene') for w in batch):
   if args.partial:break
   raise ValueError(f'Missing scene choices: {missing}')
  job={'id':f'academy-b4-{i//4+1:03d}','cells':[dict(index=j,word=w['word'],meaning=w['meaning'],filename=w['filename'],scene=w['scene']) for j,w in enumerate(batch)]}
  jobs.append(job);prompt_jobs.append(dict(job,prompt=STYLE+'\n'.join(f"{POSITIONS[c['index']]} — {c['word']} ({c['meaning']}): {c['scene']}" for c in job['cells'])))
 # Stable prompt IDs are fixed by the complete classification, even during partial authoring.
 write(OUT/'prompt-jobs.json',prompt_jobs)
 if not missing:
  plan={'format_version':1,'book_id':4,'word_count':len(words),'width':320,'height':320,'format':'PNG','max_bytes':200000,'style_reference':'Design/2026-10-11-word-illustration-pilot/sources/academy-pilot-02.png','words':prepared,'jobs':jobs}
  old=read(OUT/'plan.json') if (OUT/'plan.json').exists() else None
  if old:
   old_words={w['word']:w for w in old['words']}
   for w in prepared:
    previous=old_words.get(w['word'],{})
    for field in ['review_status']:
     if previous.get(field):w[field]=previous[field]
  write(OUT/'plan.json',plan)
  write(OUT/'semantic-plan.json',{'format_version':1,'book_id':4,'summary':dict(Counter(w['kind'] for w in prepared)),'words':prepared})
 print('Kinds:',dict(Counter(w['kind'] for w in prepared)))
 print('Stable atlases:',len(prompt_jobs),'of',(len(pics)+3)//4,'; missing scenes:',len(missing))
 if missing:print('Next missing:',missing[:16])
if __name__=='__main__':main()
