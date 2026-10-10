#!/usr/bin/env python3
"""Capture real store scenes in independent QA simulators; never launch the production app."""

import argparse
import json
import os
from pathlib import Path
import plistlib
import re
import signal
import subprocess
import time

ROOT = Path(__file__).resolve().parents[1]
MARKER = re.compile(r"NCE_STORE\|(READY|START|END|DONE)\|([A-Za-z-]+)\|([a-z0-9-]+)\|([0-9.]+)")
BUNDLE = "com.palmgame.NCEALL.resourceqa.storemedia"


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--device", required=True)
    parser.add_argument("--label", required=True, choices=["iphone", "ipad"])
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--without-building", action="store_true")
    args = parser.parse_args()
    output = args.output.resolve() / args.label
    output.mkdir(parents=True, exist_ok=False)
    env = dict(os.environ, DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer", NSUnbufferedIO="YES")
    subprocess.run(["xcrun", "simctl", "status_bar", args.device, "override", "--time", "09:41", "--dataNetwork", "wifi",
                    "--wifiMode", "active", "--wifiBars", "3", "--batteryState", "charged", "--batteryLevel", "100"], env=env, check=True)
    result = output / "capture.xcresult"
    command = ["xcodebuild", "-project", "NCE_ALL.xcodeproj", "-scheme", "NCE_Content_QA", "-configuration", "Debug",
               "-destination", f"platform=iOS Simulator,id={args.device}", "-derivedDataPath", "/private/tmp/NCEStoreMedia-20261006",
               "-resultBundlePath", str(result), "-parallel-testing-enabled", "NO",
               "-only-testing:NCEContentUITests/NCEContentUITests/testCaptureStoreMedia",
               f"NCE_APP_BUNDLE_IDENTIFIER={BUNDLE}", "CODE_SIGNING_ALLOWED=NO",
               "test-without-building" if args.without_building else "test"]
    session = {"device": args.device, "label": args.label, "bundle_identifier": BUNDLE, "xcresult": str(result), "recordings": {}}
    recorder = None
    recorder_log = None
    build = None
    try:
        build = subprocess.Popen(command, cwd=ROOT, env=env, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, text=True, bufsize=1)
        with (output / "xcodebuild.log").open("w") as log:
            for line in build.stdout:
                log.write(line)
                log.flush()
                match = MARKER.search(line)
                if not match:
                    continue
                event, language, scene, timestamp = match.groups()
                print(f"{args.label}: {language} {event} {scene}", flush=True)
                if event == "READY":
                    if recorder is not None:
                        raise RuntimeError("Overlapping recordings")
                    info_path = Path("/private/tmp/NCEStoreMedia-20261006/Build/Products/Debug-iphonesimulator/NCE_ALL.app/Info.plist")
                    with info_path.open("rb") as info_file:
                        info = plistlib.load(info_file)
                    session["capture_bundle_version"] = info["CFBundleShortVersionString"]
                    session["capture_bundle_build"] = info["CFBundleVersion"]
                    movie = output / f"{language}-raw.mov"
                    recorder_log = (output / f"{language}-recording.log").open("w+")
                    recorder = subprocess.Popen(["xcrun", "simctl", "io", args.device, "recordVideo", "--codec=h264", "--mask=ignored", str(movie)],
                                                env=env, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE, text=True)
                    deadline = time.monotonic() + 15
                    started = None
                    # simctl emits this line when the first encoded frame is available.
                    while time.monotonic() < deadline:
                        message = recorder.stderr.readline()
                        recorder_log.write(message)
                        recorder_log.flush()
                        if "Recording started" in message:
                            started = time.time()
                            break
                        if recorder.poll() is not None:
                            raise RuntimeError(f"Recorder failed: {language}")
                    if started is None:
                        raise RuntimeError("Recorder did not start")
                    session["recordings"][language] = {"path": str(movie), "first_frame_host_epoch": started, "markers": []}
                else:
                    session["recordings"][language]["markers"].append({"event": event, "scene": scene, "epoch": float(timestamp)})
                    if event == "DONE":
                        recorder.send_signal(signal.SIGINT)
                        _, trailing = recorder.communicate(timeout=30)
                        recorder_log.write(trailing)
                        recorder_log.close()
                        if recorder.returncode != 0:
                            raise RuntimeError(f"Recorder exit status {recorder.returncode}")
                        recorder = recorder_log = None
                (output / "session.json").write_text(json.dumps(session, indent=2) + "\n")
        code = build.wait()
        if code:
            raise RuntimeError(f"xcodebuild failed ({code}); inspect {output / 'xcodebuild.log'}")
        if set(session["recordings"]) != {"zh-Hans", "zh-Hant", "ja", "ko"}:
            raise RuntimeError("Missing language recordings")
        print(f"Completed {args.label}: {result}", flush=True)
    finally:
        if recorder is not None and recorder.poll() is None:
            recorder.send_signal(signal.SIGINT)
            recorder.communicate(timeout=30)
        if recorder_log is not None:
            recorder_log.close()
        if build is not None and build.poll() is None:
            build.terminate()
            build.wait(timeout=30)


if __name__ == "__main__":
    main()
