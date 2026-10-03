#!/usr/bin/env python3
"""Run the built iOS playback tests against an existing iPhone Simulator."""

import argparse
import json
import os
from pathlib import Path
import re
import subprocess
import sys


def select_device(configuration, requested_id=None):
    candidates = []
    for runtime, devices in configuration.get("devices", {}).items():
        match = re.fullmatch(r"com\.apple\.CoreSimulator\.SimRuntime\.iOS-(\d+(?:-\d+)*)", runtime)
        if not match:
            continue
        version = tuple(int(part) for part in match.group(1).split("-"))
        for device in devices:
            kind = device.get("deviceTypeIdentifier", "")
            is_phone = ".iPhone-" in kind or (not kind and device.get("name", "").startswith("iPhone"))
            if device.get("isAvailable") and is_phone and device.get("udid"):
                candidates.append((version, runtime, device))
    if requested_id:
        candidates = [item for item in candidates if item[2]["udid"].lower() == requested_id.lower()]
    if not candidates:
        raise ValueError("No available iPhone iOS Simulator matches the request.")
    # Prefer the newest installed iOS runtime, then an already booted device.
    # Local callers can select their assigned device to avoid concurrent UI work.
    candidates.sort(key=lambda item: (
        item[0], item[2].get("state") == "Booted", item[2].get("name", ""), item[2]["udid"]
    ), reverse=True)
    return candidates[0][1:]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--products", required=True, type=Path, help="build-for-testing Build/Products directory")
    parser.add_argument("--result", required=True, type=Path, help="Fresh .xcresult output path")
    parser.add_argument("--device-id", help="Optional existing iPhone Simulator UDID for local runs")
    args = parser.parse_args()
    root = Path(__file__).resolve().parent.parent
    products = args.products.resolve()
    result = args.result.resolve()
    if not products.is_dir():
        parser.error("--products must be an existing build-for-testing products directory")
    runs = sorted(path for path in products.glob("AetherFilm-iOS_*.xctestrun") if path.is_file())
    if len(runs) != 1:
        parser.error("--products must contain exactly one AetherFilm-iOS_*.xctestrun")
    if os.path.lexists(args.result) or os.path.lexists(result):
        parser.error("--result must be a fresh output path; existing results are preserved")
    media = root / ".build" / "PlaybackFixtures"
    required = (
        "clip-h264.mp4", "clip-hevc.mov", "clip-mpeg4.avi", "clip-multitrack.mkv",
        "clip-smb-long.mp4", "clip-4k-hevc.mp4", "external.srt", "external.ass", "external.vtt", "broken.mkv",
        "clip-short-gop.mp4", "clip-short-gop-tail.json",
    )
    missing = [name for name in required if not (media / name).is_file()]
    if missing:
        parser.error("Generate all playback fixtures first; missing: " + ", ".join(missing))
    launcher = root / "scripts" / "test_smb_integration.py"
    runner = root / "PlaybackTests" / "run_smb_playback.py"
    if not launcher.is_file() or not runner.is_file():
        parser.error("The SMB fixture launcher or playback runner is missing")
    try:
        listing = subprocess.run(["xcrun", "simctl", "list", "devices", "available", "-j"],
                                 check=True, capture_output=True, text=True)
        runtime, device = select_device(json.loads(listing.stdout), args.device_id)
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        parser.error("Cannot select an existing iPhone Simulator: " + str(error))
    result.parent.mkdir(parents=True, exist_ok=True)
    print("Playback Simulator: " + device["name"] + " (" + runtime + ")", flush=True)
    command = [
        sys.executable, str(launcher), "--bootstrap-only", "--media-folder", str(media), "--",
        sys.executable, str(runner), "--all-playback", "--xctestrun", str(runs[0]),
        "--destination", "platform=iOS Simulator,id=" + device["udid"], "--result", str(result),
    ]
    return subprocess.run(command, cwd=root, check=False).returncode


if __name__ == "__main__":
    raise SystemExit(main())
