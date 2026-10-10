#!/usr/bin/env python3
"""Build Japanese/Korean offline overlays using a local, build-only translation model."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import sqlite3
import subprocess
import tempfile
import time
import zipfile

from build_chinese_localizations import APP, DATA, DOCS, WORDS, save_json, sha, strings_file, ui_keys

MODEL = "facebook/m2m100_418M"
REVISION = "55c2e61bbf05dfb8d7abccdc3fae6fc8512fd636"
POS = re.compile(r"\b(n|v|vt|vi|a|adj|ad|adv|pron|prep|conj|int|num|aux|art)\.", re.I)


def phrase_key(text):
    return text.strip().replace("？", "?").replace("！", "!").casefold()


def english_overrides():
    return json.loads((DOCS / "english-phrase-overrides.json").read_text())["phrases"]


def sources():
    with sqlite3.connect(f"file:{DATA / 'NCE.db'}?mode=ro", uri=True) as db:
        rows = db.execute("SELECT word_name, word_translation FROM words ORDER BY id").fetchall()
        words = dict(rows)
        lessons = [name for (name,) in db.execute("SELECT name FROM play_list_lessons")]
        generic = {value for table, field in [("play_learn_mode", "name"), ("word_book", "name_cn"), ("play_list_books", "name")]
                   for (value,) in db.execute(f"SELECT {field} FROM {table}") if value}
    for word, record in json.loads((WORDS / "editorial-overrides.json").read_text())["overrides"].items():
        if record.get("translation"):
            words[word] = record["translation"]
    sentences = {}
    for book in range(1, 5):
        with zipfile.ZipFile(DATA / f"lesson-packs/book{book}.zip") as archive:
            for name in sorted(archive.namelist()):
                if name.endswith(".lrc"):
                    parts = archive.read(name).decode("utf-8").strip().split("－")
                    if len(parts) < 2:
                        raise ValueError(f"Invalid sentence: {name}")
                    sentences[Path(name).stem] = {"english": parts[0], "chinese": parts[1]}
    return words, lessons, sentences, generic


def word_variants():
    with sqlite3.connect(f"file:{DATA / 'NCE.db'}?mode=ro", uri=True) as db:
        rows = db.execute("SELECT DISTINCT word_name, word_translation FROM words").fetchall()
    editorial = json.loads((WORDS / "editorial-overrides.json").read_text())["overrides"]
    return {(word, editorial.get(word, {}).get("translation") or text) for word, text in rows}


def fingerprints():
    paths = [DATA / "NCE.db", WORDS / "editorial-overrides.json",
             *(DATA / f"lesson-packs/book{number}.zip" for number in range(1, 5))]
    return {str(path.relative_to(APP)): sha(path) for path in paths}


def image_sources():
    return json.loads((DOCS.parent / "word-resources/generated-images.json").read_text())["assets"]


def localized_images(locale, texts):
    ledger_path = DOCS / f"{locale}-images.json"
    previous = json.loads(ledger_path.read_text()) if ledger_path.exists() else {"assets": []}
    previous = {row["path"]: row for row in previous["assets"]}
    assets, jobs, mapping, reused = [], [], {}, []
    with tempfile.TemporaryDirectory(prefix=f"nce-{locale}-images-") as directory:
        temporary = Path(directory)
        for source in image_sources():
            word = source["word"]
            token = hashlib.sha256(word.encode()).hexdigest()[:12]
            relative = f"jpg/localized-{token}--{locale}.jpg"
            job = {key: source[key] for key in ("kind", "word", "diagram", "icons", "generated_source") if key in source}
            job.update({"path": relative, "caption": texts[source["caption"]],
                        "card_title": "意味" if locale == "ja" else "뜻",
                        "source_path": source["path"], "source_sha256": sha(WORDS / source["path"]),
                        "review_status": "machine_translation_native_review_pending"})
            path = WORDS / relative
            existing = previous.get(relative)
            if path.exists():
                if not existing or sha(path) != existing["sha256"]:
                    raise ValueError(f"Refusing to overwrite a modified or unrecorded image: {path}")
                if all(existing.get(key) == value for key, value in job.items()):
                    assets.append(existing)
                    mapping[word] = relative
                    continue
            jobs.append({**job, "output": str(temporary / path.name)})
        executable = temporary / "renderer"
        if jobs:
            subprocess.run(["xcrun", "clang", "-fobjc-arc", "-framework", "AppKit",
                str(APP.parent / "Tools/render_word_image.m"), "-o", str(executable)], check=True)
        for offset in range(0, len(jobs), 100):
            batch = jobs[offset:offset + 100]
            for job in batch:
                if job.get("generated_source"):
                    job["source_image"] = str(APP.parent / "ContentPipeline/word-images" / job["generated_source"])
            save_json(temporary / "jobs.json", batch)
            command = [str(executable), str(temporary / "jobs.json"), str(APP.parent / "ContentPipeline/word-images/twemoji")]
            result = subprocess.run(command, capture_output=True, text=True)
            if result.returncode:
                if "CaptionOverflow" not in result.stderr:
                    raise RuntimeError(result.stderr or f"Picture renderer failed: {result.returncode}")
                for job in batch:
                    if Path(job["output"]).exists():
                        continue
                    save_json(temporary / "jobs.json", [job])
                    single = subprocess.run(command, capture_output=True, text=True)
                    if single.returncode:
                        if "CaptionOverflow" not in single.stderr:
                            raise RuntimeError(single.stderr or "Picture renderer failed")
                        reused.append({"word": job["word"], "source_path": job["source_path"],
                            "reason": "localized_caption_does_not_fit_at_minimum_font_size", "caption": job["caption"]})
                        print(f"Retaining original picture for {locale}/{job['word']}: caption does not fit", flush=True)
            for job in batch:
                if not Path(job["output"]).exists():
                    continue
                Path(job["output"]).replace(WORDS / job["path"])
                row = {key: value for key, value in job.items() if key not in ("output", "source_image")}
                path = WORDS / row["path"]
                row.update({"sha256": sha(path), "bytes": path.stat().st_size, "width": 128, "height": 128})
                assets.append(row)
                mapping[row["word"]] = row["path"]
            save_json(ledger_path, {"format_version": 1, "locale": locale, "max_bytes_per_image": 8192, "assets": assets, "reused_originals": reused})
    retained = set(mapping.values())
    for relative, row in previous.items():
        path = WORDS / relative
        if relative not in retained and path.exists():
            if not re.fullmatch(rf"jpg/localized-[0-9a-f]{{12}}--{locale}\.jpg", relative) or sha(path) != row["sha256"]:
                raise ValueError(f"Refusing to remove a modified or unowned variant: {path}")
            path.unlink()
    save_json(ledger_path, {"format_version": 1, "locale": locale, "max_bytes_per_image": 8192,
                           "assets": sorted(assets, key=lambda row: row["word"]), "reused_originals": reused})
    return mapping, assets, reused


def review_queue(locale, overlay):
    _, _, sentences, _ = sources()
    script = re.compile(r"[\u3040-\u30ff\u3400-\u9fff]" if locale == "ja" else r"[\uac00-\ud7af]")
    def reasons_for(value, source_length):
        reasons = []
        if not script.search(value):
            reasons.append("no_target_script_may_be_a_proper_name_or_untranslated_text")
        if len(value) > max(80, source_length * 4):
            reasons.append("unusually_long_output")
        if re.search(r"(.{2,20})\1\1", value):
            reasons.append("repeated_output")
        return reasons

    flagged, meanings, captions = [], [], []
    for key, row in sentences.items():
        value = overlay["sentences"][key]
        reasons = reasons_for(value, len(row["english"]))
        if reasons:
            flagged.append({"section": "sentence", "key": key, "english": row["english"], "translation": value, "reasons": reasons})
    for word, variants in overlay["word_meanings"].items():
        for source, value in variants.items():
            meaning = value.split("：" if locale == "ja" else ": ", 1)[-1]
            reasons = reasons_for(meaning, len(source))
            if reasons:
                meanings.append({"section": "word_meaning", "word": word, "source": source, "translation": value, "reasons": reasons})
    for asset in image_sources():
        value = overlay["texts"][asset["caption"]]
        reasons = reasons_for(value, len(asset["caption"]))
        if reasons:
            captions.append({"section": "image_caption", "word": asset["word"], "source": asset["caption"], "translation": value, "reasons": reasons})
    save_json(DOCS / f"{locale}-review-queue.json", {"format_version": 1, "locale": locale,
              "status": "machine_flags_not_human_approval", "native_review_required_for_all_new_translations": True,
              "flagged_sentences": flagged, "flagged_word_meanings": meanings, "flagged_image_captions": captions})
    return {"machine_flagged_sentences": len(flagged), "machine_flagged_word_meanings": len(meanings),
            "machine_flagged_image_captions": len(captions)}


class LocalTranslator:
    def __init__(self, model_dir, converted_dir, cache_dir, threads):
        import ctranslate2
        from transformers import M2M100Tokenizer
        self.tokenizer = M2M100Tokenizer.from_pretrained(str(model_dir), local_files_only=True)
        self.engine = ctranslate2.Translator(str(converted_dir), device="cpu", compute_type="int8", intra_threads=threads)
        self.cache_dir = cache_dir

    def translate(self, requests, target):
        path = self.cache_dir / f"{target}.json"
        cache = json.loads(path.read_text()) if path.exists() else {"model": MODEL, "revision": REVISION, "translations": {}}
        if cache["model"] != MODEL or cache["revision"] != REVISION:
            raise ValueError("Translation cache belongs to another model")
        output = cache["translations"]
        fallback_inputs = {}
        editorial = json.loads((WORDS / "editorial-overrides.json").read_text())["overrides"]
        for word, meaning in sorted(word_variants()):
            fallback_inputs[POS.sub("", meaning).strip()] = editorial.get(word, {}).get("display") or word
        for asset in image_sources():
            fallback_inputs[asset["caption"]] = editorial.get(asset["word"], {}).get("display") or asset["word"]
        for source in ("en", "zh"):
            pending = sorted((text for code, text in requests if code == source and f"{source}:{text}" not in output), key=len)
            self.tokenizer.src_lang = source
            start = time.monotonic()
            for offset in range(0, len(pending), 24):
                batch = pending[offset:offset + 24]
                tokens = [self.tokenizer.convert_ids_to_tokens(self.tokenizer.encode(text)) for text in batch]
                if any(len(row) > 512 for row in tokens):
                    raise ValueError("Source exceeds model context; do not silently truncate")
                prefix = [self.tokenizer.lang_code_to_token[target]]
                results = self.engine.translate_batch(tokens, target_prefix=[prefix] * len(tokens),
                            beam_size=3, max_decoding_length=384, repetition_penalty=1.05)
                for text, result in zip(batch, results):
                    tokens = result.hypotheses[0][1:]
                    value = self.tokenizer.decode(self.tokenizer.convert_tokens_to_ids(tokens), skip_special_tokens=True).strip()
                    if not value or len(tokens) >= 384:
                        alternative = fallback_inputs.get(text) if source == "zh" else None
                        if not alternative:
                            raise ValueError(f"Empty or truncated translation: {source}:{text}")
                        self.tokenizer.src_lang = "en"
                        alternative_tokens = self.tokenizer.convert_ids_to_tokens(self.tokenizer.encode(alternative))
                        retried = self.engine.translate_batch([alternative_tokens], target_prefix=[prefix],
                                    beam_size=4, max_decoding_length=128)[0].hypotheses[0][1:]
                        self.tokenizer.src_lang = source
                        value = self.tokenizer.decode(self.tokenizer.convert_tokens_to_ids(retried), skip_special_tokens=True).strip()
                        if not value or len(retried) >= 128:
                            raise ValueError(f"Word-name fallback also failed: {source}:{text}/{alternative}")
                        cache.setdefault("fallbacks", {})[f"{source}:{text}"] = {"english_word": alternative, "translation": value,
                                    "review_status": "word_sense_review_required"}
                    output[f"{source}:{text}"] = value
                save_json(path, cache)
                print(f"{target}/{source}: {min(offset + 24, len(pending))}/{len(pending)} ({time.monotonic() - start:.0f}s)", flush=True)
        return output


def render(locale, overrides, translator):
    words, lessons, sentences, generic = sources()
    entries = overrides[locale]
    phrases = english_overrides()
    requests = set()
    for word, text in word_variants():
        if (word not in entries["words"] and not entries.get("word_meanings", {}).get(word, {}).get(text)
                and POS.sub("", text).strip() not in entries["texts"]):
            requests.add(("zh", POS.sub("", text).strip()))
    for key, row in sentences.items():
        if key not in entries["sentences"] and not phrases.get(phrase_key(row["english"]), {}).get(locale):
            requests.add(("en", row["english"]))
    for name in lessons:
        parts = name.split("－")
        if len(parts) >= 3 and not phrases.get(phrase_key(parts[1]), {}).get(locale):
            requests.add(("en", parts[1]))
    for text in generic:
        if text not in entries["texts"] and text not in entries["ui"]:
            requests.add(("zh", text))
    for asset in image_sources():
        if asset["caption"] not in entries["texts"] and asset["caption"] not in entries["ui"]:
            requests.add(("zh", asset["caption"]))
    generated = translator.translate(requests, locale)
    texts = {**entries["ui"], **entries["texts"]}
    meanings = {}
    variants = {}
    for word, text in sorted(word_variants()):
        if entries.get("word_meanings", {}).get(word, {}).get(text):
            value = entries["word_meanings"][word][text]
        elif word in entries["words"]:
            value = entries["words"][word]
        else:
            labels = list(dict.fromkeys(entries["pos"][tag.lower()] for tag in POS.findall(text)))
            prefix = ("・" if locale == "ja" else "/").join(labels)
            source = POS.sub("", text).strip()
            translated = entries["texts"].get(source) or generated["zh:" + source]
            value = (prefix + ("：" if locale == "ja" else ": ") if prefix else "") + translated
        variants.setdefault(word, {})[text] = value
        if text == words[word]:
            meanings[word] = value
        texts.setdefault(text, value)
    sentence_texts = {}
    for key, row in sentences.items():
        value = entries["sentences"].get(key) or phrases.get(phrase_key(row["english"]), {}).get(locale) or generated["en:" + row["english"]]
        sentence_texts[key] = value
        texts.setdefault(row["chinese"], value)
    for name in lessons:
        parts = name.split("－")
        if len(parts) < 3:
            raise ValueError(f"Invalid lesson title: {name}")
        match = re.fullmatch(r"第(\d+)课", parts[0])
        if not match:
            raise ValueError(f"Unexpected lesson number: {parts[0]}")
        title = ("第" + match[1] + "課") if locale == "ja" else ("제" + match[1] + "과")
        translated = phrases.get(phrase_key(parts[1]), {}).get(locale) or generated["en:" + parts[1]]
        texts[parts[0]] = title
        texts.setdefault(parts[2], translated)
        texts[name] = "－".join([title, parts[1], translated])
    for text in generic:
        if text not in texts:
            texts[text] = generated["zh:" + text]
    texts.update(entries["texts"])
    texts.update(entries["ui"])
    for asset in image_sources():
        text = asset["caption"]
        if text not in entries["texts"] and text not in entries["ui"]:
            texts[text] = generated["zh:" + text]
    return {"format_version": 1, "locale": locale, "review_status": "machine_translation_native_review_pending",
            "texts": texts, "words": meanings, "word_meanings": variants, "sentences": sentence_texts, "images": {}}


def verify():
    overrides = json.loads((DOCS / "east-asian-overrides.json").read_text())["localizations"]
    words, lessons, sentences, generic = sources()
    report = json.loads((DOCS / "east-asian-build-report.json").read_text())
    if report["source_fingerprints"] != fingerprints():
        raise ValueError("Source changed; rebuild the Japanese/Korean overlays")
    if report["override_fingerprint"] != sha(DOCS / "east-asian-overrides.json"):
        raise ValueError("Editorial overrides changed; rebuild the Japanese/Korean overlays")
    if report["phrase_override_fingerprint"] != sha(DOCS / "english-phrase-overrides.json"):
        raise ValueError("Common phrase overrides changed; rebuild the overlays")
    for code in ("ja", "ko"):
        overlay = json.loads((DATA / f"localizations/{code}.json").read_text())
        if set(overlay["words"]) != set(words) or set(overlay["sentences"]) != set(sentences):
            raise ValueError(f"Incomplete learning translation coverage: {code}")
        if {(word, text) for word, values in overlay["word_meanings"].items() for text in values} != word_variants():
            raise ValueError(f"Missing lesson-specific word senses: {code}")
        if any(not isinstance(value, str) or not value.strip()
               for variants in overlay["word_meanings"].values() for value in variants.values()):
            raise ValueError(f"Empty lesson-specific word meaning: {code}")
        if not set(lessons).issubset(overlay["texts"]) or not generic.issubset(overlay["texts"]):
            raise ValueError(f"Missing lesson/mode/book text: {code}")
        if set(overrides[code]["ui"]) != ui_keys():
            raise ValueError(f"Missing or stale UI keys: {code}")
        for key, value in overrides[code]["ui"].items():
            if re.findall(r"%(?:@|[dflu]+)", key) != re.findall(r"%(?:@|[dflu]+)", value):
                raise ValueError(f"Placeholder mismatch: {code}/{key}")
        for relative, checksum in report["localizations"][code]["files"].items():
            if sha(APP / relative) != checksum:
                raise ValueError(f"Generated file changed: {relative}")
        for section in ("words", "sentences", "texts"):
            if any(not isinstance(value, str) or not value.strip() for value in overlay[section].values()):
                raise ValueError(f"Empty translated value: {code}/{section}")
        ledger = json.loads((DOCS / f"{code}-images.json").read_text())
        if overlay["images"] != {row["word"]: row["path"] for row in ledger["assets"]}:
            raise ValueError(f"Image mapping differs from ledger: {code}")
        for row in ledger["assets"]:
            path = WORDS / row["path"]
            if sha(path) != row["sha256"] or path.stat().st_size > 8192 or sha(WORDS / row["source_path"]) != row["source_sha256"]:
                raise ValueError(f"Changed or oversized localized image: {row['path']}")
        print(f"Verified {code}: {len(words)} words, {len(sentences)} sentences, {len(lessons)} lessons, {len(ui_keys())} UI strings")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--verify", action="store_true")
    parser.add_argument("--model-dir", type=Path)
    parser.add_argument("--converted-dir", type=Path)
    parser.add_argument("--cache-dir", type=Path, default=DOCS.parent.parent / "ResourceSources/localization-cache")
    parser.add_argument("--threads", type=int, default=4)
    args = parser.parse_args()
    if args.verify:
        verify()
        return
    if not args.model_dir or not args.converted_dir:
        parser.error("Generation requires --model-dir and --converted-dir; no network calls are made")
    overrides = json.loads((DOCS / "east-asian-overrides.json").read_text())["localizations"]
    before = fingerprints()
    translator = LocalTranslator(args.model_dir, args.converted_dir, args.cache_dir, args.threads)
    report = {"format_version": 1, "model": MODEL, "revision": REVISION,
              "model_url": "https://huggingface.co/facebook/m2m100_418M", "model_license": "MIT",
              "model_bundled": False, "runtime_network_translation": False,
              "source_fingerprints": before, "native_editorial_review": "pending", "localizations": {}}
    report["override_fingerprint"] = sha(DOCS / "east-asian-overrides.json")
    report["phrase_override_fingerprint"] = sha(DOCS / "english-phrase-overrides.json")
    for code in ("ja", "ko"):
        overlay = render(code, overrides, translator)
        overlay["images"], images, reused = localized_images(code, overlay["texts"])
        flagged = review_queue(code, overlay)
        if set(overrides[code]["ui"]) != ui_keys():
            raise ValueError(f"UI catalog is incomplete: {code}")
        paths = [DATA / f"localizations/{code}.json", APP / f"{code}.lproj/Localizable.strings", APP / f"{code}.lproj/InfoPlist.strings"]
        save_json(paths[0], overlay)
        paths[1].parent.mkdir(parents=True, exist_ok=True)
        header = "/* Generated by Tools/build_east_asian_localizations.py. Edit Docs/localization/east-asian-overrides.json. */\n"
        paths[1].write_text(header + strings_file(overrides[code]["ui"]).split("\n", 1)[1], encoding="utf-8")
        paths[2].write_text(header + strings_file({"CFBundleDisplayName": overrides[code]["display_name"]}).split("\n", 1)[1], encoding="utf-8")
        fallback_history = json.loads((args.cache_dir / f"{code}.json").read_text()).get("fallbacks", {})
        corrected_fallbacks = {key: {**row, "editorial_translation": overrides[code]["texts"][key[3:]]}
                              for key, row in fallback_history.items() if key[3:] in overrides[code]["texts"]}
        report["localizations"][code] = {"words": len(overlay["words"]), "sentences": len(overlay["sentences"]),
                "word_meaning_variants": sum(len(values) for values in overlay["word_meanings"].values()),
                "text_entries": len(overlay["texts"]), "ui_strings": len(ui_keys()),
                "localized_images": len(images), "localized_image_bytes": sum(row["bytes"] for row in images),
                "original_image_fallbacks": len(reused),
                **flagged,
                "word_name_translation_fallbacks": {key: row for key, row in fallback_history.items() if key not in corrected_fallbacks},
                "editorially_corrected_word_name_fallbacks": corrected_fallbacks,
                "files": {str(path.relative_to(APP)): sha(path) for path in paths}}
    if before != fingerprints():
        raise ValueError("An original database or lesson archive changed")
    save_json(DOCS / "east-asian-build-report.json", report)
    verify()


if __name__ == "__main__":
    main()
