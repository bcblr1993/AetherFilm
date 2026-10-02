#!/usr/bin/env python3
"""Generate copyright-free, small UI fixtures. Never overwrite existing media."""
from pathlib import Path
import subprocess
import shutil

root = Path(__file__).resolve().parents[1]
folder = root / ".build/UIFixtures"
folder.mkdir(parents=True, exist_ok=True)
ffmpeg = shutil.which("ffmpeg")
if ffmpeg is None:
    raise SystemExit("ffmpeg is required for test fixtures")
for name in ["片段 01.mp4", "片段 02.mkv"]:
    destination = folder / name
    if destination.exists():
        continue
    subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin",
        "-f", "lavfi", "-i", "testsrc2=size=480x270:rate=24", "-f", "lavfi", "-i",
        "sine=frequency=440:sample_rate=48000", "-t", "30", "-c:v", "libx264", "-preset", "ultrafast",
        "-pix_fmt", "yuv420p", "-c:a", "aac", str(destination)], check=True)
print("UI fixtures ready: MP4 and MKV, 30 seconds each.")
