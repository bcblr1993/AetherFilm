#!/usr/bin/env python3
"""Generate a synthetic 4K HEVC/AAC video for real-device output acceptance."""

import argparse
from pathlib import Path
import shutil
import subprocess


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(".build/PlaybackFixtures"))
    args = parser.parse_args()
    ffmpeg = shutil.which("ffmpeg")
    if ffmpeg is None:
        raise SystemExit("ffmpeg is required; this script installs no dependencies.")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    output = folder / "clip-4k-hevc.mp4"
    if output.exists():
        raise SystemExit("4K fixture already exists. Choose a fresh output directory.")
    subprocess.run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin",
        "-f", "lavfi", "-i", "testsrc2=size=3840x2160:rate=24",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
        "-t", "6", "-c:v", "libx265", "-preset", "ultrafast", "-crf", "28",
        "-x265-params", "log-level=error", "-tag:v", "hvc1", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", str(output)
    ], check=True)
    print(f"Generated {output.name} ({output.stat().st_size} bytes)", flush=True)


if __name__ == "__main__":
    main()
