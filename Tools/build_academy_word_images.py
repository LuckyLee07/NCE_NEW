#!/usr/bin/env python3
"""Compile an Academy book's reviewed art map, coverage report and review page."""
import argparse
from collections import Counter
import hashlib
import html
import json
from pathlib import Path
import shutil
import sqlite3
import struct

ROOT=Path(__file__).resolve().parents[1]
RESOURCES=ROOT/'NCE_ALL/data/words'
DOCS=ROOT/'Docs/word-resources'

def validate_plan(plan, book):
    if plan.get('book_id') != book:
        raise ValueError(f'Plan belongs to another book: {plan.get("book_id")}')
    word_keys=[w['word'] for w in plan['words']]
    if len(word_keys) != len(set(word_keys)):
        raise ValueError('Plan contains duplicate word keys')
    database=ROOT/'NCE_ALL/data/NCE.db'
    with sqlite3.connect(database.resolve().as_uri()+'?mode=ro',uri=True) as connection:
        expected={row[0] for row in connection.execute(
            'SELECT DISTINCT word_name FROM words WHERE book_id=?',(book,))}
    actual=set(word_keys)
    if actual != expected:
        raise ValueError(f'Book {book} plan coverage differs from database: '
                         f'missing={sorted(expected-actual)}, extra={sorted(actual-expected)}')

def read_png(path):
    data=path.read_bytes()
    if data[:8]!=b'\x89PNG\r\n\x1a\n' or data[12:16]!=b'IHDR':
        raise ValueError(f'Not a PNG: {path}')
    if struct.unpack('>II',data[16:24])!=(320,320) or len(data)>200000:
        raise ValueError(f'Wrong dimensions or >200 KB: {path}')
    return {'bytes':len(data),'sha256':hashlib.sha256(data).hexdigest(),'width':320,'height':320}

def main():
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--allow-partial',action='store_true')
    parser.add_argument('--book',type=int,choices=range(1,5),default=1)
    args=parser.parse_args()
    pipeline=ROOT/f'ContentPipeline/word-images/academy-book{args.book}'
    plan=json.loads((pipeline/'plan.json').read_text())
    validate_plan(plan,args.book)
    words={w['word']:w for w in plan['words']}
    provenance={}
    for receipt_path in sorted((pipeline/'jobs').glob(f'academy-b{args.book}-*.json')):
        receipt=json.loads(receipt_path.read_text())
        for cell in receipt['cells']:
            if cell.get('superseded_by'):continue
            provenance[cell['word']]={'receipt':str(receipt_path.relative_to(ROOT)),
                'atlas_cell':cell['index'],'visual_review':receipt.get('review_status','pending')}
    (RESOURCES/'png').mkdir(exist_ok=True)
    for w in words.values():
        if w['kind']=='pilot_illustration':
            source=ROOT/w['source'];dest=RESOURCES/'png'/w['filename']
            read_png(source)
            if dest.exists() and dest.read_bytes()!=source.read_bytes():
                raise ValueError(f'Pilot file modified: {dest}')
            if not dest.exists():shutil.copyfile(source,dest)
    images={};hints={};captions={};presentations={};records=[];missing=[]
    for w in words.values():
        record={k:w[k] for k in ['word','meaning','lessons','kind']}
        if w.get('caption'):
            captions[w['word']]=w['caption'];record['caption']=w['caption']
        if w.get('presentation'):
            presentations[w['word']]=w['presentation'];record['presentation']=w['presentation']
        if w['kind']=='native_hint':
            hints[w['word']]=w['hint'];record['hint']=w['hint']
        else:
            source=words[w['same_as']] if w['kind']=='shared_illustration' else w
            if source['kind']=='shared_book_illustration':
                relative='png/'+source['source_filename']
                source_report=json.loads((DOCS/f"academy-book{source['source_book_id']}-report.json").read_text())
                source_record=next(r for r in source_report['words'] if r['word']==source['source_word'])
                if source_record.get('path')!=relative or source_record.get('status')!='ready':
                    raise ValueError(f'Invalid cross-book source: {source}')
                record['source_book_id']=source['source_book_id'];record['source_word']=source['source_word']
                record['visual_review']='explicit_sense_reviewed_reuse'
            else:relative='png/'+source['filename']
            path=RESOURCES/relative
            if not path.exists():
                missing.append(w['word']);record['status']='pending';records.append(record);continue
            record.update(read_png(path));record['path']=relative
            if source['kind']=='ai_illustration':
                review=provenance.get(source['word'])
                if not args.allow_partial and (not review or review['visual_review']!='assistant_visual_reviewed'):
                    raise ValueError(f'Image has no completed visual review: {source["word"]}')
                if review:record.update(review)
            elif source['kind']=='native_diagram':
                if not args.allow_partial and source.get('review_status')!='assistant_visual_reviewed':
                    raise ValueError(f'Diagram has no visual review: {source["word"]}')
                record['visual_review']=source.get('review_status','pending')
                record['source']='Tools/render_academy_word_diagrams.swift'
                record['diagram']=source['diagram']
            elif source['kind']=='pilot_illustration':
                record['visual_review']='user_approved_pilot'
            if w['kind']=='shared_illustration':record['same_as']=w['same_as']
            images[w['word']]=relative
        record['status']='ready';records.append(record)
    if missing and not args.allow_partial:raise ValueError(f'{len(missing)} words still need images: {missing}')
    mapping={'format_version':1,'book_id':args.book,'images':images,'hints':hints,'captions':captions,'presentations':presentations}
    (RESOURCES/('academy-image-map.json' if args.book==1 else f'academy-book{args.book}-image-map.json')).write_text(json.dumps(mapping,ensure_ascii=False,indent=2)+'\n')
    unique={r['path']:r for r in records if 'path' in r}
    total=sum(r['bytes'] for r in unique.values())
    summary={'book_id':args.book,'word_count':len(words),'covered_words':len(images)+len(hints),
             'illustrated_words':len(images),'native_hints':len(hints),'native_diagrams':sum(w['kind']=='native_diagram' for w in words.values()),'context_scenes':sum(w.get('presentation')=='scene' for w in words.values()),'unique_image_files':len(unique),
             'image_bytes':total,'largest_image_bytes':max((r['bytes'] for r in unique.values()),default=0),
             'image_size':[320,320],'image_format':'PNG','lossy_compression':False,'max_bytes_per_image':200000,
             'missing_words':missing,'kinds':dict(Counter(w['kind'] for w in words.values()))}
    report={'format_version':1,'summary':summary,'words':records}
    (DOCS/f'academy-book{args.book}-report.json').write_text(json.dumps(report,ensure_ascii=False,indent=2)+'\n')
    rows=[]
    for r in records:
        word=html.escape(r['word']);meaning=html.escape(r['meaning'])
        if 'path' in r:
            visual=f'<img loading="lazy" width="240" height="240" src="../../NCE_ALL/data/words/{r["path"]}" alt="{meaning}">'
            badge=f'{r["bytes"]/1000:.1f} KB · 320 × 320 PNG';kind='diagram' if r.get('presentation')=='diagram' else 'scene' if r.get('caption') else 'image'
            if r.get('caption'):visual+='<div class="caption">'+html.escape(r['caption'])+'</div>'
        elif 'hint' in r:
            visual='<div class="hint">'+html.escape(r['hint']).replace('\n','<br>')+'</div>'
            badge='原生例句 / 关系提示 · 目标词留空';kind='hint'
        else:
            visual='<div class="pending">待生成</div>';badge='待生成';kind='pending'
        lessons=' / '.join(str(x) for x in r['lessons'] if x is not None) or '补充词'
        rows.append(f'<article data-kind="{kind}" data-search="{html.escape(r["word"]+" "+r["meaning"]+" "+lessons,quote=True)}">{visual}<h2>{word}</h2><p>{meaning}</p><small>课次 {lessons}<br>{badge}</small></article>')
    page='''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>第一册 · 新版单词配图</title><style>
*{box-sizing:border-box}body{margin:0;background:#f7f9fc;color:#203447;font:16px -apple-system,BlinkMacSystemFont,"Segoe UI",sans-serif}header{padding:24px max(24px,calc((100% - 1220px)/2));background:#fff;position:sticky;top:0;z-index:1;border-bottom:1px solid #e2eaf2}h1{font-size:25px;margin:0 0 8px}header p{font-size:14px;color:#5d7186;margin:0 0 14px}.filters{display:flex;gap:12px;align-items:center;flex-wrap:wrap}input,select{font:inherit;border:1px solid #d5e0eb;padding:10px 12px;border-radius:10px;background:white}input{min-width:250px}main{max-width:1280px;margin:auto;padding:24px;display:grid;grid-template-columns:repeat(auto-fill,minmax(240px,1fr));gap:18px}article{background:#fff;border:1px solid #e4ebf2;border-radius:14px;padding:16px;text-align:center;overflow:hidden}img{width:100%;height:240px;object-fit:contain}.caption{font-size:16px;line-height:1.5;color:#367095;min-height:48px}.hint,.pending{height:240px;display:flex;align-items:center;justify-content:center;flex-direction:column;border-radius:12px;background:#edf6ff;color:#1879b8;font-size:20px;line-height:1.7;padding:18px;overflow-wrap:anywhere}.pending{color:#8c99a6;background:#f4f6f8}h2{font-size:22px;margin:14px 0 5px}article p{color:#607184;margin:0 0 12px}small{color:#8492a1;line-height:1.6}article[hidden]{display:none}#count{color:#61758a;font-size:14px}
</style><header><h1>第一册 · 新版单词配图</h1><p>''' + f'{len(images)} 个词使用插画 / 图解 · {len(hints)} 个词使用原生提示 · 单图不超过 200 KB · 图片共 {total/1000000:.2f} MB' + '''</p><div class="filters"><input id="query" type="search" placeholder="搜索单词、释义或课次" aria-label="搜索"><select id="kind" aria-label="类型"><option value="">全部类型</option><option value="supplement">本次新增（92）</option><option value="image">插画</option><option value="scene">情境插画＋短句</option><option value="diagram">图解</option><option value="hint">原生提示</option><option value="pending">待生成</option></select><span id="count"></span></div></header><main>'''+'\n'.join(rows)+'''</main><script>
const cards=[...document.querySelectorAll('article')],q=document.getElementById('query'),kind=document.getElementById('kind'),count=document.getElementById('count');function filter(){let n=0;for(const c of cards){c.hidden=!(c.dataset.search.toLowerCase().includes(q.value.trim().toLowerCase())&&(!kind.value||c.dataset.kind===kind.value||(kind.value==='supplement'&&['diagram','scene'].includes(c.dataset.kind))));if(!c.hidden)n++}count.textContent=n+' / '+cards.length+' 个词'}q.addEventListener('input',filter);kind.addEventListener('change',filter);filter();</script></html>'''
    if args.book!=1:
        page=page.replace('第一册',f'第{args.book}册').replace('<option value="supplement">本次新增（92）</option>','')
    (DOCS/f'academy-book{args.book}-review.html').write_text(page)
    print(json.dumps(summary,ensure_ascii=False))

if __name__=='__main__':main()
