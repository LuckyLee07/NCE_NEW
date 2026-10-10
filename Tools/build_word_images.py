#!/usr/bin/env python3
"""Compose small word graphics from attributed Twemoji icons and native diagrams."""

import argparse
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import tempfile
from urllib.parse import quote
import zipfile

ROOT = Path(__file__).resolve().parents[1]
PIPELINE = ROOT / "ContentPipeline/word-images"
DOCS = ROOT / "Docs/word-resources"
RESOURCES = ROOT / "NCE_ALL/data/words"
ARCHIVE_SHA = "d8a269885d95c78123cc0981c8c76a4c55466cdcb6c7c939434323533e6cd754"
SOURCE_URL = "https://github.com/jdecked/twemoji/tree/v17.0.3"


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def image_words(baseline, repair_path=PIPELINE / "semantic-repairs.json"):
    records = {record["word"]: record for record in baseline["words"]}
    missing = [record for record in records.values() if record["image"]["status"] == "missing"]
    if not repair_path.exists():
        return missing
    repair_manifest = json.loads(repair_path.read_text(encoding="utf-8"))
    if repair_manifest.get("format_version") != 1 or not isinstance(repair_manifest.get("repairs"), dict):
        raise ValueError("Invalid semantic-repair manifest")
    for word, repair in repair_manifest["repairs"].items():
        original = records.get(word)
        if not original or not isinstance(repair, dict) or not repair.get("note") or \
                not repair.get("previous_path") or repair["previous_path"] != original["image"]["path"]:
            raise ValueError(f"Semantic repair must identify an existing baseline image: {word}")
        missing.append(original)
    return missing


def save_json(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")


def load_recipes(path=PIPELINE / "recipes.txt"):
    recipes = {}
    for number, line in enumerate(path.read_text(encoding="utf-8").splitlines(), 1):
        if not line or line.startswith("#"):
            continue
        kind, drawing, names = line.split(";", 2)
        if kind not in ("illustration", "context", "diagram", "ai_illustration"):
            raise ValueError(f"Unknown recipe kind on line {number}")
        for name in names.split("|"):
            if name in recipes:
                raise ValueError(f"Duplicate recipe for {name!r} on line {number}")
            if kind == "diagram":
                recipes[name] = {"kind": kind, "diagram": drawing}
            elif kind == "ai_illustration":
                if Path(drawing).name != drawing or not drawing.endswith(".png"):
                    raise ValueError(f"Invalid generated source on line {number}")
                recipes[name] = {"kind": kind, "generated_source": drawing}
            else:
                recipes[name] = {"kind": kind, "icons": drawing.split(",")}
    return recipes


def clean_caption(value):
    caption = re.sub(r"^(?:(?:a|ad|n|v|vi|vt|prep|pron|aux|conj|int)\.\s*|&\s*)+", "", value).strip()
    return caption or "Meaning pending review"


def filename(word):
    slug = re.sub(r"[^a-z0-9]+", "-", word.lower()).strip("-")[:70] or "word"
    return f"{slug}--{hashlib.sha256(word.encode()).hexdigest()[:12]}.jpg"


def prepare_sources(archive, needed):
    if digest(archive) != ARCHIVE_SHA:
        raise ValueError("Unexpected Twemoji archive checksum; do not consume it")
    destination = PIPELINE / "twemoji"
    destination.mkdir(parents=True, exist_ok=True)
    sources = []
    with zipfile.ZipFile(archive) as zipped:
        for name in sorted(needed):
            if not re.fullmatch(r"[a-f0-9]+(?:-[a-f0-9]+)*", name):
                raise ValueError(f"Unsafe icon name: {name}")
            data = zipped.read(f"twemoji-17.0.3/assets/72x72/{name}.png")
            path = destination / f"{name}.png"
            if path.exists() and path.read_bytes() != data:
                raise ValueError(f"Changed source icon: {name}")
            if not path.exists():
                path.write_bytes(data)
            sources.append({"icon": name, "sha256": hashlib.sha256(data).hexdigest(), "bytes": len(data)})
        license_data = zipped.read("twemoji-17.0.3/LICENSE-GRAPHICS")
    license_root = RESOURCES / "licenses"
    license_root.mkdir(parents=True, exist_ok=True)
    (license_root / "Twemoji-CC-BY-4.0.txt").write_bytes(license_data)
    save_json(PIPELINE / "sources.json", {"format_version": 1, "project": "Twemoji", "version": "17.0.3",
              "commit": "b6b55fef1e8636b540a6d016a4729ca8cdf2e60b", "source_url": SOURCE_URL,
              "archive_url": "https://codeload.github.com/jdecked/twemoji/zip/refs/tags/v17.0.3",
              "archive_sha256": ARCHIVE_SHA, "license": "CC-BY-4.0", "icons": sources})


def write_review(ledger):
    lines = ["# New Word Image Review", "", "All images are drafts pending human semantic review. Context graphics are mnemonic cues; meaning cards are deliberately not illustrations of an object.", "",
             "| Reviewed | Word | Meaning | Type | Image | Editorial hold |", "| --- | --- | --- | --- | --- | --- |"]
    from audit_word_resources import table_cell
    for asset in ledger["assets"]:
        link = quote("../../NCE_ALL/data/words/" + asset["path"], safe="/")
        lines.append(f"| [ ] | {table_cell(asset['word'])} | {table_cell(asset['caption'])} | {asset['kind']} | [JPG]({link}) | {'yes' if asset['editorial_review_required'] else ''} |")
    path = DOCS / "image-review.md"
    if not path.exists():
        path.write_text("\n".join(lines) + "\n", encoding="utf-8")
    else:
        existing = path.read_text(encoding="utf-8")
        existing = sync_review_rows(existing, lines[6:])
        path.write_text(existing, encoding="utf-8")
        reviewed_words = {match.group(1).strip() for match in re.finditer(r"^\| \[[ xX]\] \| ([^|]+) \|", existing, re.MULTILINE)}
        additional = [line for line in lines[6:] if line.split(" | ", 3)[1].strip() not in reviewed_words]
        if additional:
            path.write_text(existing.rstrip() + "\n\n## Additional Entries\n\n" + "\n".join(lines[4:6] + additional) + "\n", encoding="utf-8")
    rows = []
    for asset in ledger["assets"]:
        link = quote("../../NCE_ALL/data/words/" + asset["path"], safe="/")
        rows.append(f'<figure data-word="{html.escape(asset["word"].lower(), quote=True)}" data-kind="{asset["kind"]}"><img loading="lazy" width="128" height="128" src="{link}" alt="{html.escape(asset["caption"], quote=True)}"><figcaption><b>{html.escape(asset["word"])}</b><small>{html.escape(asset["caption"])}<br>{asset["kind"]}</small></figcaption></figure>')
    page = '''<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1"><title>新增单词配图审校</title>
<style>body{margin:24px;font:14px system-ui;color:#252525}header{position:sticky;top:0;background:white;padding:12px 0;border-bottom:1px solid #ddd}input,select{font:inherit;padding:8px;margin:4px;max-width:90%}main{display:grid;grid-template-columns:repeat(auto-fill,minmax(156px,1fr));gap:20px;margin-top:20px}figure{margin:0;min-width:0;text-align:center}img{object-fit:contain;border:1px solid #eee}figcaption{overflow-wrap:anywhere}small{display:block;color:#666;margin-top:6px}[hidden]{display:none!important}</style>
<header><h1>新增单词配图审校</h1><input id="query" type="search" placeholder="单词或释义"><select id="kind"><option value="">全部</option><option>illustration</option><option>ai_illustration</option><option>context</option><option>diagram</option><option>meaning_card</option></select><span id="count"></span></header><main>''' + "\n".join(rows) + '''</main><script>
const figures=[...document.querySelectorAll('figure')],query=document.querySelector('#query'),kind=document.querySelector('#kind');
function filter(){let count=0;for(const f of figures){f.hidden=!(f.textContent.toLowerCase().includes(query.value.toLowerCase())&&(!kind.value||f.dataset.kind===kind.value));if(!f.hidden)count++;}document.querySelector('#count').textContent=count+' / '+figures.length;}
query.addEventListener('input',filter);kind.addEventListener('change',filter);filter();</script></html>'''
    (DOCS / "image-review.html").write_text(page, encoding="utf-8")


def sync_review_rows(existing, generated_rows):
    # Update generated metadata, preserving human checkboxes and extra note columns.
    def cells(line):
        return [cell.strip() for cell in re.split(r"(?<!\\)\|", line)]
    current = {cells(line)[2]: cells(line) for line in generated_rows}
    output = []
    for line in existing.splitlines():
        old = cells(line)
        if len(old) >= 8 and old[1] in ("[ ]", "[x]", "[X]") and old[2] in current:
            fresh = current[old[2]]
            line = "| " + " | ".join([old[1], *fresh[2:7], *old[7:-1]]) + " |"
        output.append(line)
    return "\n".join(output) + "\n"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--twemoji-archive", type=Path, required=True)
    parser.add_argument("--include-meaning-cards", action="store_true", help="Use visibly labelled meaning cards for words without a precise visual recipe")
    parser.add_argument("--rebuild-generated", action="store_true", help="Replace only checksum-verified outputs from this pipeline; preserve all original and manually changed assets")
    parser.add_argument("--only-words", nargs="+", help="Build a specific batch of baseline-missing image words")
    args = parser.parse_args()
    baseline = json.loads((DOCS / "baseline.json").read_text(encoding="utf-8"))
    if digest(ROOT / "NCE_ALL/data/NCE.db") != baseline["database_sha256"]:
        raise ValueError("Database changed since the baseline; review the word list first")
    recipes = load_recipes()
    overrides = json.loads((RESOURCES / "editorial-overrides.json").read_text())["overrides"]
    words = image_words(baseline)
    if not args.include_meaning_cards:
        words = [record for record in words if record["word"] in recipes]
    if args.only_words:
        selected = set(args.only_words)
        if selected - {record["word"] for record in words}:
            raise ValueError("Batch contains words outside baseline missing images and recorded semantic repairs")
        words = [record for record in words if record["word"] in selected]
    ledger_path = DOCS / "generated-images.json"
    old = json.loads(ledger_path.read_text(encoding="utf-8")) if ledger_path.exists() else {"assets": []}
    assets = {asset["word"]: asset for asset in old["assets"]}
    preserved_path = PIPELINE / "preserved-images.json"
    if not preserved_path.exists():
        original = {record["image"]["path"] for record in baseline["words"] if record["image"]["path"]}
        save_json(preserved_path, {"database_sha256": baseline["database_sha256"],
                                  "images": {path: digest(RESOURCES / path) for path in sorted(original)}})
    needed = {icon for record in words for icon in recipes.get(record["word"], {}).get("icons", [])}
    needed.update(icon for asset in assets.values() for icon in asset.get("icons", []))
    prepare_sources(args.twemoji_archive, needed)
    jobs = []
    for record in words:
        word = record["word"]
        recipe = recipes.get(word, {"kind": "meaning_card"}).copy()
        translation = record["references"][0]["translation"]
        caption = clean_caption(translation)
        caption = overrides.get(word, {}).get("caption", caption)
        editorial = word in {"Mew Jersey", "St.Petersbrug", "Justiteombudsman", "anchor"} or "\ufffd" in translation or "\ue002" in translation
        if word == "anchor":
            caption = "\u951a\uff1b\u629b\u951a"
        relative = f"jpg/{filename(word)}"
        path = RESOURCES / relative
        if path.exists():
            if word not in assets or assets[word]["sha256"] != digest(path):
                raise ValueError(f"Refusing to overwrite an existing or modified image: {path}")
            if not args.rebuild_generated and (assets[word]["caption"] != caption or any(assets[word].get(key) != value for key, value in recipe.items())):
                raise ValueError(f"Recipe changed for {word}; review and version it explicitly")
            if not args.rebuild_generated:
                continue
        jobs.append({"word": word, "caption": caption, "output": str(path), "path": relative,
                     "editorial_review_required": editorial, **recipe})
    with tempfile.TemporaryDirectory(prefix="nce-word-images-") as temporary:
        temporary = Path(temporary)
        renderer = temporary / "renderer"
        subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "AppKit", str(ROOT / "Tools/render_word_image.m"), "-o", str(renderer)], check=True)
        for start in range(0, len(jobs), 40):
            batch = [{**job, "output": str(temporary / Path(job["output"]).name)} for job in jobs[start:start + 40]]
            for job in batch:
                if job.get("generated_source"):
                    job["source_image"] = str(PIPELINE / job["generated_source"])
            job_path = temporary / "jobs.json"
            save_json(job_path, batch)
            subprocess.run([str(renderer), str(job_path), str(PIPELINE / "twemoji")], check=True)
            for job in batch:
                staging = Path(job["output"])
                path = RESOURCES / job["path"]
                if path.exists() and (job["word"] not in assets or digest(path) != assets[job["word"]]["sha256"]):
                    raise ValueError(f"Image changed during build; will not replace {path}")
                staging.replace(path)
                asset = {key: value for key, value in job.items() if key not in ("output", "source_image")}
                asset.update({"sha256": digest(path), "bytes": path.stat().st_size, "width": 128, "height": 128,
                              "review_status": "pending_semantic_review", "source": "built-in-image_gen" if job.get("generated_source") else ("Twemoji-17.0.3/CC-BY-4.0" if job.get("icons") else "project-native-diagram-or-text")})
                assets[asset["word"]] = asset
            ledger = {"format_version": 1, "database_sha256": baseline["database_sha256"], "jpeg_quality": 0.55,
                      "max_bytes_per_image": 8192, "assets": [assets[key] for key in sorted(assets)]}
            save_json(ledger_path, ledger)
    ledger = json.loads(ledger_path.read_text(encoding="utf-8"))
    save_json(RESOURCES / "generated-image-map.json", {"format_version": 1, "images": {asset["word"]: asset["path"] for asset in ledger["assets"]}})
    write_review(ledger)
    counts = {kind: sum(asset["kind"] == kind for asset in ledger["assets"]) for kind in ("illustration", "ai_illustration", "context", "diagram", "meaning_card")}
    print(json.dumps({"images": len(assets), "bytes": sum(asset["bytes"] for asset in assets.values()), "kinds": counts}, indent=2))


if __name__ == "__main__":
    main()
