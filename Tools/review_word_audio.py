#!/usr/bin/env python3
"""Independent local waveform/ASR review; never declares human listening approval."""

import argparse
import array
import hashlib
import json
import math
from pathlib import Path
import re
import sys
import wave

ROOT = Path(__file__).resolve().parents[1]


def normalized(text):
    return re.sub(r"[^a-z0-9]", "", text.lower())


def waveform(path):
    with wave.open(str(path)) as audio:
        if (audio.getnchannels(), audio.getsampwidth(), audio.getframerate()) != (1, 2, 24000):
            raise ValueError("Unexpected PCM format")
        samples = array.array("h", audio.readframes(audio.getnframes()))
    if sys.byteorder != "little":
        samples.byteswap()
    peak = max(abs(sample) for sample in samples) / 32768
    rms = math.sqrt(sum(sample * sample for sample in samples) / len(samples)) / 32768
    active = [index for index, sample in enumerate(samples) if abs(sample) > 164]
    return {"duration_seconds": len(samples) / 24000, "peak": peak, "rms": rms,
            "clipped_samples": sum(abs(sample) >= 32760 for sample in samples),
            "active_seconds": (active[-1] - active[0] + 1) / 24000 if active else 0,
            "leading_silence_seconds": active[0] / 24000 if active else None,
            "trailing_silence_seconds": (len(samples) - active[-1] - 1) / 24000 if active else None}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--model-file", type=Path, required=True)
    parser.add_argument("--only-words", nargs="+")
    parser.add_argument("--beam-size", type=int, choices=(1, 5), default=1)
    parser.add_argument("--retry-unmatched-from", type=Path, help="Review only checksum-matched nonexact transcripts from an earlier pass")
    args = parser.parse_args()
    if not args.model_file.is_file():
        parser.error("A pre-existing local Whisper model file is required; no model downloads")
    import torch
    import whisper
    import numpy as np
    from scipy.signal import resample_poly

    print("Loading cached model...", flush=True)
    torch.set_num_threads(4)
    engine = whisper.load_model(str(args.model_file), device="cpu")
    print("Model loaded", flush=True)
    model_checksum = hashlib.sha256(args.model_file.read_bytes()).hexdigest()
    ledger = json.loads((ROOT / "Docs/word-resources/generated-audio.json").read_text())
    assets = ledger["assets"]
    if args.retry_unmatched_from:
        earlier = json.loads(args.retry_unmatched_from.read_text())
        retry = {review["word"]: review["sha256"] for review in earlier["assets"] if not review["lexical_match"]}
        assets = [asset for asset in assets if retry.get(asset["word"]) == asset["sha256"]]
    if args.only_words:
        assets = [asset for asset in assets if asset["word"] in set(args.only_words)]
    previous = json.loads(args.output.read_text()) if args.output.exists() else {"assets": []}
    reviews = {review["word"]: review for review in previous["assets"]}
    for number, asset in enumerate(assets, 1):
        path = ROOT / "NCE_ALL/data/words" / asset["path"]
        checksum = hashlib.sha256(path.read_bytes()).hexdigest()
        if checksum != asset["sha256"]:
            raise ValueError("Audio differs from generation ledger: " + asset["word"])
        if asset["word"] in reviews and reviews[asset["word"]]["sha256"] == checksum:
            continue
        signal = waveform(path)
        # The additions have a known PCM layout; decode locally without an ffmpeg subprocess.
        with wave.open(str(path)) as audio:
            pcm = np.frombuffer(audio.readframes(audio.getnframes()), dtype="<i2").astype(np.float32) / 32768
        pcm = resample_poly(pcm, 2, 3).astype(np.float32)
        result = engine.transcribe(pcm, language="en", temperature=0, beam_size=args.beam_size,
                                   fp16=False, condition_on_previous_text=False, verbose=None)
        transcript = result["text"].strip()
        review = {"word": asset["word"], "path": asset["path"], "sha256": checksum,
                  "expected_spoken_text": asset["spoken_text"], "transcript": transcript,
                  "lexical_match": normalized(transcript) == normalized(asset["spoken_text"]),
                  "waveform": signal, "status": "ai_review_requires_decision",
                  "human_listening_approved": False}
        reviews[asset["word"]] = review
        output = {"format_version": 1, "reviewer": "local Whisper small.en plus waveform checks",
                  "method": "Independent transcription with no expected-word prompt; not a pronunciation score or human listening review",
                  "model_sha256": model_checksum,
                  "beam_size": args.beam_size,
                  "assets": sorted(reviews.values(), key=lambda item: item["word"])}
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(json.dumps(output, ensure_ascii=True, indent=2) + "\n")
        print(f"[{number}/{len(assets)}] {asset['word']}: {transcript!r}, match={review['lexical_match']}", flush=True)


if __name__ == "__main__":
    main()
