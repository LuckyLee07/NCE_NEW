#!/usr/bin/env python3
"""Bind explicit AI visual review and offline ASR evidence to current asset hashes."""

import argparse
from collections import Counter
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
DOCS = ROOT / "Docs/word-resources"
RESOURCES = ROOT / "NCE_ALL/data/words"


def read(path):
    return json.loads(path.read_text(encoding="utf-8"))


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save(path, value):
    path.write_text(json.dumps(value, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")


def verify_bindings(assets, reviews, allow_subset=False):
    current = {asset["word"]: asset for asset in assets}
    if len({row["word"] for row in reviews}) != len(reviews):
        raise ValueError("Duplicate review word")
    if not allow_subset and set(current) != {row["word"] for row in reviews}:
        raise ValueError("Incomplete review coverage")
    for row in reviews:
        asset = current.get(row["word"])
        if not asset or row["sha256"] != asset["sha256"] or row["path"] != asset["path"] or \
                digest(RESOURCES / row["path"]) != row["sha256"]:
            raise ValueError("Review is stale or assigned to the wrong asset: " + row["word"])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--record-ai-visual-review", action="store_true", help="Use only after actually inspecting every final contact page")
    parser.add_argument("--contacts", type=Path)
    args = parser.parse_args()
    images = read(DOCS / "generated-images.json")["assets"]
    audio = read(DOCS / "generated-audio.json")["assets"]
    first = read(DOCS / "audio-ai-review.json")
    second = read(DOCS / "audio-ai-second-pass.json")
    verify_bindings(audio, first["assets"])
    verify_bindings(audio, second["assets"], allow_subset=True)
    first_rows = {row["word"]: row for row in first["assets"]}
    if {row["word"] for row in second["assets"]} != {row["word"] for row in first["assets"] if not row["lexical_match"]}:
        raise ValueError("Second pass must cover all first-pass lexical mismatches")
    review_path = DOCS / "image-ai-review.json"
    if args.record_ai_visual_review:
        if not args.contacts:
            parser.error("The inspected contact-page directory is required")
        pages = []
        for page in range(1, math.ceil(len(images) / 60) + 1):
            path = args.contacts / f"page-{page:02}.png"
            pages.append({"page": page, "path": str(path), "sha256": digest(path)})
        findings = read(DOCS / "semantic-findings.json")
        changed = {word: correction["action"] for correction in findings["corrections"] for word in correction["words"]}
        rows = [{"word": asset["word"], "path": asset["path"], "sha256": asset["sha256"],
                 "caption": asset["caption"], "kind": asset["kind"], "contact_page": index // 60 + 1,
                 "status": "ai_draft_reviewed", "human_semantic_approved": False,
                 "correction": changed.get(asset["word"])} for index, asset in enumerate(images)]
        save(review_path, {"format_version": 1, "review_date": findings["review_date"], "reviewer": findings["reviewer"],
             "method": "Visual inspection of all final contact pages, exact recipe/caption review, and targeted dictionary/course-context checks; not human approval",
             "ledger_sha256": digest(DOCS / "generated-images.json"), "findings_sha256": digest(DOCS / "semantic-findings.json"),
             "contact_pages": pages, "assets": rows})
    visual = read(review_path)
    verify_bindings(images, visual["assets"])
    if visual["ledger_sha256"] != digest(DOCS / "generated-images.json") or \
            visual["findings_sha256"] != digest(DOCS / "semantic-findings.json"):
        raise ValueError("Visual-review metadata changed after review")
    if any(row["human_semantic_approved"] for row in visual["assets"]) or \
            any(row["human_listening_approved"] for row in first["assets"] + second["assets"]):
        raise ValueError("AI receipts must not assert human approval")
    second_rows = {row["word"]: row for row in second["assets"]}
    lexical = sum(row["lexical_match"] or second_rows.get(word, {}).get("lexical_match", False) for word, row in first_rows.items())
    signals = [row["waveform"] for row in first["assets"]]
    summary = {"format_version": 1, "review_date": visual["review_date"],
               "image_ai_reviewed": len(images), "image_kinds": dict(Counter(asset["kind"] for asset in images)),
               "image_total_bytes": sum(asset["bytes"] for asset in images),
               "image_max_bytes": max(asset["bytes"] for asset in images),
               "audio_first_pass_count": len(first["assets"]), "audio_second_pass_count": len(second["assets"]),
               "audio_exact_lexical_match_either_pass": lexical, "audio_nonexact_requires_listening": len(audio) - lexical,
               "audio_clipped_samples": sum(signal["clipped_samples"] for signal in signals),
               "audio_silent_or_very_short_active": sum(signal["active_seconds"] < 0.15 for signal in signals),
               "audio_edges_with_no_padding": sum(signal["leading_silence_seconds"] == 0 or signal["trailing_silence_seconds"] == 0 for signal in signals),
               "human_semantic_approved": 0, "human_listening_approved": 0,
               "physical_device_ui_acceptance": "deferred_by_user_device_locked",
               "specialist_pronunciation_holds": ["Justiteombudsman", "Kituro", "Wayle"],
               "limits": ["Exact ASR transcripts do not certify pronunciation, stress or naturalness.",
                          "Nonexact transcripts include articles, spelling variants, abbreviations and possible speech errors; keep the raw evidence for listening review.",
                          "No audio was uploaded for review; cached local Whisper used no expected-word prompt."]}
    save(DOCS / "review-summary.json", summary)
    print(json.dumps(summary, indent=2))


if __name__ == "__main__":
    main()
