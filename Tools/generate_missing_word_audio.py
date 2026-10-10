#!/usr/bin/env python3
"""Generate only baseline missing WAVs locally; preserve all existing recordings."""

import argparse
import hashlib
import importlib.metadata
import json
from pathlib import Path
import tempfile
import wave

ROOT = Path(__file__).resolve().parents[1]
MODEL_SHA256 = "beb0d1848dee9a49da392cc3df26958d46cfa35d321edf434f52949153f0df3a"
VOICES_SHA256 = "bca610b8308e8d99f32e6fe4197e7ec01679264efed0cac9140fe9c29f1fbf7d"


def sha256(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def save_ledger(path, data):
    temporary = path.with_suffix(".tmp")
    temporary.write_text(json.dumps(data, ensure_ascii=True, indent=2) + "\n", encoding="utf-8")
    temporary.replace(path)


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--model-dir", type=Path, required=True)
    parser.add_argument("--baseline", type=Path, default=ROOT / "Docs/word-resources/baseline.json")
    parser.add_argument("--resources", type=Path, default=ROOT / "NCE_ALL/data/words")
    parser.add_argument("--ledger", type=Path, default=ROOT / "Docs/word-resources/generated-audio.json")
    parser.add_argument("--limit", type=int)
    parser.add_argument("--only-words", nargs="+")
    parser.add_argument("--rebuild-generated", action="store_true", help="Replace only selected, checksum-verified pipeline additions; never original recordings")
    args = parser.parse_args()
    model = args.model_dir / "kokoro-v1.0.onnx"
    voices = args.model_dir / "voices-v1.0.bin"
    if sha256(model) != MODEL_SHA256 or sha256(voices) != VOICES_SHA256:
        parser.exit(1, "Unexpected model or voice file checksum; refusing to load.\n")

    # Optional generation dependencies are not needed by the App or audit tools.
    import numpy as np
    import onnxruntime as ort
    from kokoro_onnx import Kokoro

    options = ort.SessionOptions()
    options.intra_op_num_threads = 4
    options.inter_op_num_threads = 1
    session = ort.InferenceSession(str(model), sess_options=options, providers=["CPUExecutionProvider"])
    engine = Kokoro.from_session(session, str(voices))
    overrides = json.loads((ROOT / "Docs/word-resources/spoken-text-overrides.json").read_text())["overrides"]
    baseline = json.loads(args.baseline.read_text())
    targets = [record for record in baseline["words"] if record["audio"]["status"] == "missing"]
    if args.rebuild_generated and not args.only_words:
        parser.error("Explicit --only-words selection is required for replacement")
    if args.only_words:
        selected = set(args.only_words)
        if selected - {record["word"] for record in targets}:
            parser.error("Selection includes a word outside the original missing-audio set")
        targets = [record for record in targets if record["word"] in selected]
    if args.limit:
        targets = targets[:args.limit]
    ledger = json.loads(args.ledger.read_text()) if args.ledger.exists() else {
        "format_version": 1,
        "source": "local AI synthesis; not textbook publisher recordings",
        "model": {
            "name": "Kokoro-82M v1.0", "license": "Apache-2.0",
            "source": "https://huggingface.co/hexgrad/Kokoro-82M",
            "model_url": "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/kokoro-v1.0.onnx",
            "voices_url": "https://github.com/thewh1teagle/kokoro-onnx/releases/download/model-files-v1.1/voices-v1.0.bin",
            "model_sha256": MODEL_SHA256, "voices_sha256": VOICES_SHA256,
        },
        "inference": {"library": "kokoro-onnx", "version": importlib.metadata.version("kokoro-onnx"),
                      "voice": "bf_emma", "language": "en-gb", "speed": 0.9,
                      "sample_rate": 24000, "format": "mono PCM16 WAV"},
        "assets": [],
    }
    completed = {record["word"]: record for record in ledger["assets"]}
    for number, target in enumerate(targets, 1):
        word = target["word"]
        if any(character in word for character in ("/", "\\", "\x00")):
            parser.exit(1, f"Unsafe output word: {word!r}\n")
        destination = args.resources / "wav" / f"{word}.wav"
        if word in completed:
            if not destination.exists() or sha256(destination) != completed[word]["sha256"]:
                parser.exit(1, f"Existing generated audio changed: {word}\n")
            if not args.rebuild_generated:
                continue
        elif destination.exists():
            parser.exit(1, f"Refusing to overwrite existing audio: {word}\n")
        override = overrides.get(word, {})
        spoken_text = override.get("text", word)
        phonemes = override.get("phonemes") or engine.tokenizer.phonemize(spoken_text, "en-gb")
        audio, sample_rate = engine.create(phonemes, voice="bf_emma", speed=0.9, lang="en-gb", is_phonemes=True)
        audio = np.asarray(audio, dtype=np.float32).reshape(-1)
        if not np.isfinite(audio).all() or not 0.15 <= len(audio) / sample_rate <= 15:
            parser.exit(1, f"Invalid generated duration or samples: {word}\n")
        peak = float(np.max(np.abs(audio)))
        rms = float(np.sqrt(np.mean(audio ** 2)))
        if peak < 0.01 or rms < 0.002:
            parser.exit(1, f"Silent or near-silent generated audio: {word}\n")
        audio *= min(2.0, 0.75 / peak)
        fade = min(int(sample_rate * 0.005), len(audio) // 2)
        audio[:fade] *= np.linspace(0, 1, fade)
        audio[-fade:] *= np.linspace(1, 0, fade)
        audio = np.concatenate([np.zeros(int(sample_rate * 0.12)), audio, np.zeros(int(sample_rate * 0.18))])
        pcm = (np.clip(audio, -1, 1) * 32767).astype("<i2")
        destination.parent.mkdir(parents=True, exist_ok=True)
        with tempfile.TemporaryDirectory(prefix="nce-word-audio-") as staging:
            temporary = Path(staging) / "audio.wav"
            with wave.open(str(temporary), "wb") as output:
                output.setnchannels(1)
                output.setsampwidth(2)
                output.setframerate(sample_rate)
                output.writeframes(pcm.tobytes())
            if destination.exists():
                if word not in completed or sha256(destination) != completed[word]["sha256"]:
                    parser.exit(1, f"Audio changed during generation: {word}\n")
                archive = ROOT / "ContentPipeline/word-audio/revisions" / (completed[word]["sha256"] + ".wav")
                archive.parent.mkdir(parents=True, exist_ok=True)
                old_bytes = destination.read_bytes()
                if archive.exists() and archive.read_bytes() != old_bytes:
                    parser.exit(1, "Revision archive checksum mismatch\n")
                if not archive.exists():
                    with archive.open("xb") as handle:
                        handle.write(old_bytes)
                ledger.setdefault("revisions", []).append({**completed[word], "archive": str(archive.relative_to(ROOT)), "replacement_note": override.get("note", "Explicit selected rebuild")})
            temporary.replace(destination)
        record = {
            "word": word, "path": f"wav/{word}.wav", "spoken_text": spoken_text,
            "phonemes": phonemes, "sha256": sha256(destination),
            "duration_seconds": round(len(pcm) / sample_rate, 4),
            "peak": round(float(np.max(np.abs(audio))), 6),
            "rms": round(float(np.sqrt(np.mean(audio ** 2))), 6),
            "qa_status": "pending_listening_review",
            "editorial_review_required": override.get("editorial_review_required", False),
        }
        if override:
            record["spoken_text_note"] = override["note"]
        if word in completed:
            ledger["assets"] = [record if previous["word"] == word else previous for previous in ledger["assets"]]
        else:
            ledger["assets"].append(record)
        save_ledger(args.ledger, ledger)
        print(f"[{number}/{len(targets)}] {word}: {record['duration_seconds']:.2f}s", flush=True)
    print(f"Generated additions in ledger: {len(ledger['assets'])}")


if __name__ == "__main__":
    main()
