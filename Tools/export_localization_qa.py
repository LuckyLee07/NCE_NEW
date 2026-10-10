#!/usr/bin/env python3
"""Export passed native localization QA evidence and screenshots from xcresult bundles."""

import argparse
import hashlib
import json
from pathlib import Path
import re
import shutil
import subprocess
import tempfile

from PIL import Image

ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--result", action="append", required=True, help="LABEL=/absolute/result.xcresult")
    parser.add_argument("--output", type=Path, default=ROOT / "Docs/localization")
    args = parser.parse_args()
    output = args.output.resolve()
    screenshots = output / "ui-screenshots"
    screenshots.mkdir(parents=True, exist_ok=True)
    report = {"format_version": 1, "qa_bundle_identifier": "com.palmgame.NCEALL.resourceqa.localization",
              "production_records_touched": False, "ads_enabled": False, "store_assets_uploaded": False,
              "screenshots_upload_ready": False,
              "physical_device_test": "pending", "native_editorial_review": "pending", "runs": [], "screenshots": []}
    report["visual_followups"] = [
        "iPhone 13 mini on iOS 26.2 shows a red rdar:45025538 compatibility banner and black borders; passing interaction checks do not resolve this visual issue.",
        "Confirm on physical devices and prepare supported App Store screenshot sizes before upload."
    ]
    for result in args.result:
        label, path = result.split("=", 1)
        if not re.fullmatch(r"[a-z0-9-]+", label):
            raise ValueError("Invalid result label")
        summary = json.loads(subprocess.check_output(["xcrun", "xcresulttool", "get", "test-results", "summary", "--path", path, "--compact"], text=True))
        if summary["result"] != "Passed" or summary["failedTests"] or not summary["passedTests"]:
            raise ValueError(f"Do not export failed or empty runs: {label}")
        report["runs"].append({"label": label, "xcresult_path": path, "summary": summary})
        with tempfile.TemporaryDirectory(prefix="nce-localization-evidence-") as temporary:
            export = Path(temporary) / "attachments"
            subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", path, "--output-path", str(export)], check=True, stdout=subprocess.DEVNULL)
            for test in json.loads((export / "manifest.json").read_text()):
                for attachment in test["attachments"]:
                    if attachment["isAssociatedWithFailure"] or not attachment["exportedFileName"].endswith(".png"):
                        continue
                    name = attachment["suggestedHumanReadableName"].split("_0_")[0]
                    if not re.fullmatch(r"[A-Za-z0-9-]+", name):
                        raise ValueError(f"Unexpected screenshot name: {name}")
                    # These earlier captures precede the final software-caption terminology correction.
                    if label == "iphone" and name.endswith("word-software"):
                        continue
                    source = export / attachment["exportedFileName"]
                    target = screenshots / f"{label}-{name}.png"
                    shutil.copyfile(source, target)
                    with Image.open(target) as image:
                        image.load()
                        width, height = image.size
                    report["screenshots"].append({"path": str(target.relative_to(output)), "width": width, "height": height,
                        "sha256": hashlib.sha256(target.read_bytes()).hexdigest(), "label": label,
                        "capture_timestamp": attachment["timestamp"]})
    report["total_passed_ui_tests"] = sum(run["summary"]["passedTests"] for run in report["runs"])
    report["screenshots"].sort(key=lambda item: item["path"])
    (output / "ui-validation.json").write_text(json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"Exported {len(report['screenshots'])} native screenshots from {report['total_passed_ui_tests']} passed tests.")


if __name__ == "__main__":
    main()
