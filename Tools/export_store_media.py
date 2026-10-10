#!/usr/bin/env python3
"""Export passed native screenshots and trim actual recordings to App Store preview specs."""

import argparse
import hashlib
import html
import json
import os
from pathlib import Path
import plistlib
import re
import shutil
import subprocess
import tempfile

from PIL import Image, ImageChops, ImageStat

ROOT = Path(__file__).resolve().parents[1]
LANGUAGES = ["zh-Hans", "zh-Hant", "ja", "ko", "en-US", "en-CA"]
UPLOAD_LANGUAGES = ["zh-Hans", "zh-Hant", "ja", "ko", "en-CA"]
SCENES = ["01-home", "02-lesson", "03-word", "04-practice", "05-wordbook"]
PREVIEW_LAYOUT = "full_frame_native_capture"
SCENE_DURATION = 4.8
POSTER_TIME = 1.0
DEVICE_SPECS = {"iphone": {"screenshots": (1290, 2796), "video": (886, 1920), "slot": "iPhone 6.9-inch"},
                "ipad": {"screenshots": (2048, 2732), "video": (1200, 1600), "slot": "iPad 13-inch"}}


def preview_filter(label, offset):
    width, height = DEVICE_SPECS[label]["video"]
    # Preserve all native UI pixels; no canvas, caption band or framing.
    return (f"fps=30,trim=start={offset:.6f}:duration={SCENE_DURATION},setpts=PTS-STARTPTS,"
            f"scale={width}:{height}:flags=lanczos,setsar=1")


def verify_native_frame(actual, reference):
    assert actual.size == reference.size, "Native frame dimensions differ"
    width, height = actual.size
    difference = ImageChops.difference(actual.convert("RGB"), reference.convert("RGB"))
    borders = [(0, 0, width, height // 10), (0, height * 9 // 10, width, height),
               (0, 0, width // 10, height), (width * 9 // 10, 0, width, height)]
    mean_error = sum(ImageStat.Stat(difference).mean) / 3
    edge_error = max(sum(ImageStat.Stat(difference.crop(box)).mean) / 3 for box in borders)
    assert mean_error < 8 and edge_error < 8, "Rendered frame is not a full-frame native capture"
    return {"mean_rgb_error": round(mean_error, 4), "max_edge_rgb_error": round(edge_error, 4)}


def verify_framing(path, recording, edits, ffmpeg, env):
    errors = {}
    with tempfile.TemporaryDirectory(prefix="nce-native-framing-") as temporary:
        temporary = Path(temporary)
        selection = "+".join(f"eq(n\\,{index * 144 + 36})" for index in range(len(SCENES)))
        run([ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(path), "-vf",
             f"select={selection},scale=120:-2:flags=lanczos", "-vsync", "0",
             str(temporary / "actual-%02d.bmp")], env)
        for index, edit in enumerate(edits):
            reference = temporary / f"reference-{index}.bmp"
            # Compare against the raw capture independently of the export filter.
            filters = (f"fps=30,trim=start={edit['source_offset_seconds']:.6f}:duration={SCENE_DURATION},"
                       "setpts=PTS-STARTPTS,select=eq(n\\,36),scale=120:-2:flags=lanczos,setsar=1")
            run([ffmpeg, "-hide_banner", "-loglevel", "error", "-i", recording["path"],
                 "-vf", filters, "-frames:v", "1", str(reference)], env)
            with Image.open(temporary / f"actual-{index + 1:02d}.bmp") as actual, Image.open(reference) as native:
                errors[edit["scene"]] = verify_native_frame(actual, native)
    return {"status": "passed", "sampled_scenes": len(errors), "source_comparison": errors}


def run(command, env, **kwargs):
    return subprocess.run(command, env=env, check=True, **kwargs)


def probe(path, ffprobe, env):
    return json.loads(subprocess.check_output([ffprobe, "-v", "error", "-show_streams", "-show_format", "-of", "json", str(path)], env=env, text=True))


def file_info(path, base):
    return {"path": str(path.relative_to(base)), "bytes": path.stat().st_size, "sha256": hashlib.sha256(path.read_bytes()).hexdigest()}


def verify_video(path, spec, ffprobe, env):
    metadata = probe(path, ffprobe, env)
    video = next(stream for stream in metadata["streams"] if stream["codec_type"] == "video")
    audio = next(stream for stream in metadata["streams"] if stream["codec_type"] == "audio")
    numerator, denominator = map(int, video["avg_frame_rate"].split("/"))
    duration = float(metadata["format"]["duration"])
    assert (video["width"], video["height"]) == spec["video"]
    assert video["codec_name"] == "h264" and video["pix_fmt"] == "yuv420p"
    assert video["profile"] == "High" and video["level"] <= 40
    assert 10_000_000 <= int(video.get("bit_rate", 0)) <= 12_000_000
    assert numerator / denominator <= 30 and video["field_order"] == "progressive"
    assert audio["codec_name"] == "aac" and audio["channels"] == 2 and audio["sample_rate"] == "48000"
    assert 15 <= duration <= 30 and path.stat().st_size <= 500 * 1024 * 1024
    # Decode every frame, not just the metadata header.
    ffmpeg = ffprobe.replace("ffprobe", "ffmpeg")
    run([ffmpeg, "-v", "error", "-i", str(path), "-f", "null", "-"], env, stdout=subprocess.DEVNULL)
    return {"duration_seconds": duration, "width": video["width"], "height": video["height"], "fps": numerator / denominator,
            "codec": "H.264", "profile": video["profile"], "level": video["level"], "pixel_format": video["pix_fmt"],
            "audio": "silent AAC stereo 48 kHz", "video_bit_rate": int(video.get("bit_rate", 0)), "all_frames_decode": True}


def verify_motion(path, label, ffmpeg, env):
    selections = [index * 144 + offset for index in range(5) for offset in (36, 132)]
    selection = "+".join(f"eq(n\\,{number})" for number in selections)
    motion = {}
    with tempfile.TemporaryDirectory(prefix="nce-preview-motion-") as temporary:
        temporary = Path(temporary)
        filters = f"select={selection},scale=120:-2"
        run([ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(path), "-vf", filters, "-vsync", "0", str(temporary / "frame-%02d.bmp")], env)
        frames = sorted(temporary.glob("frame-*.bmp"))
        assert len(frames) == 10
        for index, scene in enumerate(SCENES):
            with Image.open(frames[2 * index]) as first, Image.open(frames[2 * index + 1]) as second:
                difference = ImageChops.difference(first.convert("L"), second.convert("L"))
                histogram = difference.histogram()
                changed = sum(histogram[13:]) / (difference.width * difference.height)
                assert max(first.convert("RGB").getextrema()[channel][1] - first.convert("RGB").getextrema()[channel][0] for channel in range(3)) > 100
                motion[scene] = round(changed, 6)
        assert motion["02-lesson"] > 0.003, "Lesson navigation is not visible in the clip"
        assert motion["05-wordbook"] > 0.003, "Wordbook scrolling is not visible in the clip"
    return motion


def make_preview(recording, label, language, directory, ffmpeg, ffprobe, env, report):
    spec = DEVICE_SPECS[label]
    width, height = spec["video"]
    source = next(stream for stream in probe(recording["path"], ffprobe, env)["streams"] if stream["codec_type"] == "video")
    assert (source["width"], source["height"]) == spec["screenshots"], "Wrong native capture dimensions"
    assert abs((width / height) / (source["width"] / source["height"]) - 1) < 0.001
    starts = {item["scene"]: item["epoch"] for item in recording["markers"] if item["event"] == "START"}
    ends = {item["scene"]: item["epoch"] for item in recording["markers"] if item["event"] == "END"}
    assert set(starts) == set(ends) == set(SCENES)
    with tempfile.TemporaryDirectory(prefix="nce-preview-") as temporary:
        temporary = Path(temporary)
        clips = []
        edits = []
        for index, scene in enumerate(SCENES):
            offset = starts[scene] - recording["first_frame_host_epoch"] + 1.0
            assert offset >= 0 and ends[scene] - starts[scene] > 6.8
            clip = temporary / f"clip-{index}.mp4"
            # Simulator recordings are variable-frame-rate; fill static gaps before trimming.
            # Seeking directly into a still scene can otherwise produce an audio-only clip.
            filters = preview_filter(label, offset)
            run([ffmpeg, "-hide_banner", "-loglevel", "error", "-i", recording["path"],
                 "-f", "lavfi", "-i", "anullsrc=channel_layout=stereo:sample_rate=48000", "-t", "4.8", "-map", "0:v:0", "-map", "1:a:0",
                 "-vf", filters, "-c:v", "libx264", "-preset", "fast", "-profile:v", "high", "-level:v", "4.0", "-pix_fmt", "yuv420p",
                 "-b:v", "11M", "-minrate", "11M", "-maxrate", "11M", "-bufsize", "24M", "-x264-params", "nal-hrd=cbr:force-cfr=1",
                 "-c:a", "aac", "-b:a", "256k", "-ar", "48000", "-ac", "2", "-movflags", "+faststart", str(clip)], env)
            clip_metadata = probe(clip, ffprobe, env)
            assert [stream["codec_type"] for stream in clip_metadata["streams"]] == ["video", "audio"]
            assert 4.75 <= float(clip_metadata["format"]["duration"]) <= 4.9
            clips.append(clip)
            edits.append({"scene": scene, "source_offset_seconds": offset, "duration_seconds": SCENE_DURATION,
                          "video_filter": filters})
        concat = temporary / "concat.txt"
        concat.write_text("".join(f"file '{clip}'\n" for clip in clips))
        target = directory / "app-preview.mp4"
        run([ffmpeg, "-hide_banner", "-loglevel", "error", "-f", "concat", "-safe", "0", "-i", str(concat),
             "-c", "copy", "-movflags", "+faststart", str(target)], env)
    info = file_info(target, report["base"])
    info.update(verify_video(target, spec, ffprobe, env))
    info["actual_app_motion_changed_pixel_fraction"] = verify_motion(target, label, ffmpeg, env)
    info["native_framing_validation"] = verify_framing(target, recording, edits, ffmpeg, env)
    info.update({"locale": language, "device": label, "actual_ui_locale": "zh-Hans" if language.startswith("en-") else language,
                 "source_recording": recording["path"], "source_pixels": [source["width"], source["height"]],
                 "edits": edits, "poster_time_seconds": POSTER_TIME, "preview_layout": PREVIEW_LAYOUT,
                 "added_framing": False, "text_overlays": False})
    report["videos"].append(info)
    review = report["base"] / "review" / language / label
    review.mkdir(parents=True, exist_ok=True)
    run([ffmpeg, "-hide_banner", "-loglevel", "error", "-ss", str(POSTER_TIME), "-i", str(target), "-frames:v", "1", str(directory / "preview-poster.png")], env)
    run([ffmpeg, "-hide_banner", "-loglevel", "error", "-i", str(target), "-vf", "fps=5/24", "-frames:v", "5", str(review / "frame-%02d.png")], env)
    print(f"Exported {language}/{label}: preview {info['duration_seconds']:.2f}s", flush=True)


def export_images(session, output, env, report):
    label = session["label"]
    result = session["xcresult"]
    summary = json.loads(subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", result, "--compact"], env=env, text=True))
    assert summary["result"] == "Passed" and summary["failedTests"] == 0 and summary["passedTests"] > 0
    capture_version = session.get("capture_bundle_version")
    capture_build = session.get("capture_bundle_build")
    if capture_version is None:
        with Path("/private/tmp/NCEStoreMedia-20261006/Build/Products/Debug-iphonesimulator/NCE_ALL.app/Info.plist").open("rb") as info_file:
            info = plistlib.load(info_file)
        capture_version, capture_build = info["CFBundleShortVersionString"], info["CFBundleVersion"]
    report["runs"].append({"label": label, "device": session["device"], "xcresult": result, "summary": summary,
                           "capture_bundle_version": capture_version, "capture_bundle_build": capture_build})
    seen = set()
    with tempfile.TemporaryDirectory(prefix="nce-store-screenshots-") as temporary:
        exported = Path(temporary) / "attachments"
        run(["xcrun", "xcresulttool", "export", "attachments", "--path", result, "--output-path", str(exported)], env, stdout=subprocess.DEVNULL)
        for test in json.loads((exported / "manifest.json").read_text()):
            for attachment in test["attachments"]:
                if attachment["isAssociatedWithFailure"]:
                    raise ValueError("Failed capture attachment")
                name = attachment["suggestedHumanReadableName"].split("_0_")[0]
                match = re.fullmatch(r"store-(zh-Hans|zh-Hant|ja|ko)-(0[1-5]-[a-z]+)", name)
                if not match:
                    continue
                language, scene = match.groups()
                assert (language, scene) not in seen
                seen.add((language, scene))
                directory = output / "upload" / language / label
                directory.mkdir(parents=True, exist_ok=True)
                target = directory / f"{scene}.png"
                shutil.copyfile(exported / attachment["exportedFileName"], target)
                with Image.open(target) as image:
                    image.load()
                    assert image.size == DEVICE_SPECS[label]["screenshots"], (target, image.size)
                    assert image.mode in ("RGB", "RGBA")
                    if image.mode == "RGBA":
                        assert image.getextrema()[3] == (255, 255)
                    colors = image.convert("RGB").getextrema()
                    assert max(high - low for low, high in colors) > 100
                    mode = image.mode
                info = file_info(target, output)
                info.update({"locale": language, "actual_ui_locale": language, "device": label, "scene": scene,
                             "width": image.width, "height": image.height, "mode": mode, "capture_timestamp": attachment["timestamp"],
                             "native_unmodified_screenshot": True, "nonblank": True})
                report["screenshots"].append(info)
    assert seen == {(language, scene) for language in LANGUAGES[:4] for scene in SCENES}


def gallery(output):
    sections = []
    for language in LANGUAGES:
        for label in DEVICE_SPECS:
            directory = f"upload/{language}/{label}"
            figures = "".join(f'<figure><a href="{directory}/{scene}.png"><img loading="lazy" src="{directory}/{scene}.png" alt="{html.escape(scene)}"></a><figcaption>{scene}</figcaption></figure>' for scene in SCENES)
            sections.append(f'<section id="{language}-{label}"><h2>{language} / {label}</h2><div class="screens">{figures}</div><video controls preload="metadata" poster="{directory}/preview-poster.png" src="{directory}/app-preview.mp4"></video><p><a href="{directory}/app-preview.mp4">App 预览 MP4</a> · <a href="{directory}/preview-poster.png">封面参考</a></p></section>')
    navigation = '<nav>' + ' · '.join(f'<a href="#{language}-iphone">{language}</a>' for language in LANGUAGES) + '</nav>'
    page = ('<!doctype html><html lang="zh-CN"><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">'
            '<title>App Store 1.3 素材预览</title><style>body{margin:24px;font:15px system-ui;background:#f5f7f7;color:#283535}h1{font-size:24px}h2{font-size:18px}section{padding:24px 0;border-top:1px solid #ccd5d5}.screens{display:grid;grid-template-columns:repeat(5,minmax(0,1fr));gap:12px;max-width:1280px}figure{margin:0}img{display:block;width:100%;height:auto}figcaption{padding:8px 0;font-size:12px}video{margin-top:16px;width:280px;max-width:100%;height:auto}@media(max-width:700px){.screens{grid-template-columns:repeat(2,minmax(0,1fr))}}</style>'
            '<h1>App Store 1.3 无边框预览</h1><p>视频仅展示完整 App 录屏，无外框、标题区或文字叠加。加拿大英文商店页展示真实简体中文界面；en-US 为备用素材，本次不上传。</p>'
            + navigation + "".join(sections) + '</html>')
    (output / "index.html").write_text(page, encoding="utf-8")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--captures", type=Path, required=True)
    parser.add_argument("--output", type=Path, default=ROOT / "StoreAssets/1.3")
    parser.add_argument("--device", action="append", choices=list(DEVICE_SPECS), help="Export completed device runs separately")
    parser.add_argument("--resume", action="store_true", help="Continue this tool's incomplete export, validating prior file hashes")
    parser.add_argument("--ffmpeg", default="/opt/homebrew/bin/ffmpeg")
    parser.add_argument("--ffprobe", default="/opt/homebrew/bin/ffprobe")
    parser.add_argument("--library-path", help="Optional runtime-only path for an existing compatible FFmpeg library")
    args = parser.parse_args()
    output = args.output.resolve()
    partial = output / "manifest.partial.json"
    if args.resume:
        report = json.loads(partial.read_text())
        assert report["target_store_version"] == "1.3" and report["uploaded"] is False
        assert report["preview_layout"] == PREVIEW_LAYOUT, "Cannot mix legacy framed previews into this export"
        for item in report["screenshots"] + report["videos"]:
            assert file_info(output / item["path"], output)["sha256"] == item["sha256"]
        report["base"] = output
    else:
        output.mkdir(parents=True, exist_ok=False)
        report = {"format_version": 1, "base": output, "target_store_version": "1.3", "store_locales": LANGUAGES,
                  "upload_locales": UPLOAD_LANGUAGES, "preview_layout": PREVIEW_LAYOUT,
                  "app_ui_locales": LANGUAGES[:4], "uploaded": False, "review_submitted": False, "production_records_touched": False,
                  "ads_enabled_in_capture": False, "preview_audio": "silent; no unlicensed music or simulated app audio", "runs": [], "screenshots": [], "videos": []}
    env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer")
    if args.library_path:
        env["DYLD_LIBRARY_PATH"] = args.library_path
    for label in args.device or DEVICE_SPECS:
        assert label not in {run["label"] for run in report["runs"]}, "Device already exported"
        session = json.loads((args.captures / label / "session.json").read_text())
        assert session["bundle_identifier"] == "com.palmgame.NCEALL.resourceqa.storemedia"
        export_images(session, output, env, report)
        for language in LANGUAGES[:-1]:
            actual = "zh-Hans" if language == "en-US" else language
            directory = output / "upload" / language / label
            directory.mkdir(parents=True, exist_ok=True)
            if language == "en-US":
                for scene in SCENES:
                    shutil.copyfile(output / "upload/zh-Hans" / label / f"{scene}.png", directory / f"{scene}.png")
                    info = file_info(directory / f"{scene}.png", output)
                    info.update({"locale": language, "actual_ui_locale": actual, "device": label, "scene": scene,
                                 "width": DEVICE_SPECS[label]["screenshots"][0], "height": DEVICE_SPECS[label]["screenshots"][1], "native_unmodified_screenshot": True})
                    report["screenshots"].append(info)
            if language == "en-US":
                original = output / "upload/zh-Hans" / label
                for filename in ("app-preview.mp4", "preview-poster.png"):
                    shutil.copyfile(original / filename, directory / filename)
                source_info = next(item for item in report["videos"] if item["locale"] == "zh-Hans" and item["device"] == label)
                report["videos"].append(dict(source_info, **file_info(directory / "app-preview.mp4", output),
                                              locale=language, identical_to=source_info["path"]))
                shutil.copytree(output / "review/zh-Hans" / label, output / "review/en-US" / label)
            else:
                make_preview(session["recordings"][actual], label, language, directory, args.ffmpeg, args.ffprobe, env, report)
        canadian = output / "upload/en-CA" / label
        shutil.copytree(output / "upload/en-US" / label, canadian)
        for scene in SCENES:
            info = file_info(canadian / f"{scene}.png", output)
            info.update({"locale": "en-CA", "actual_ui_locale": "zh-Hans", "device": label, "scene": scene,
                         "width": DEVICE_SPECS[label]["screenshots"][0], "height": DEVICE_SPECS[label]["screenshots"][1], "native_unmodified_screenshot": True})
            report["screenshots"].append(info)
        source_info = next(item for item in report["videos"] if item["locale"] == "en-US" and item["device"] == label)
        report["videos"].append(dict(source_info, **file_info(canadian / "app-preview.mp4", output), locale="en-CA", identical_to=source_info["path"]))
        partial.write_text(json.dumps({key: value for key, value in report.items() if key != "base"}, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    if {run["label"] for run in report["runs"]} != set(DEVICE_SPECS):
        print(f"Partial export complete: {len(report['screenshots'])} screenshots and {len(report['videos'])} previews. Export the other device with --resume.", flush=True)
        return
    assert len(report["screenshots"]) == 60 and len(report["videos"]) == 12
    report["posters"] = []
    for language in LANGUAGES:
        for label, spec in DEVICE_SPECS.items():
            path = output / "upload" / language / label / "preview-poster.png"
            with Image.open(path) as poster:
                poster.load()
                assert poster.size == spec["video"]
                assert poster.mode == "RGB"
            info = file_info(path, output)
            info.update({"locale": language, "device": label, "width": spec["video"][0], "height": spec["video"][1],
                         "reference_only": True, "poster_time_seconds": POSTER_TIME})
            report["posters"].append(info)
    report.pop("base")
    report.update({"technical_validation": "passed", "visual_review": "pending", "native_language_editorial_review": "pending", "asc_processing": "not_uploaded"})
    (output / "manifest.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    partial.unlink()
    gallery(output)
    print(f"Exported 60 screenshots and 12 App previews: {output}", flush=True)


if __name__ == "__main__":
    main()
