#!/usr/bin/env python3
"""Generate a synthetic video large enough to exercise NAS range streaming."""

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
    output = folder / "clip-smb-long.mp4"
    if output.exists():
        raise SystemExit("SMB fixture already exists. Choose a fresh output directory.")
    subprocess.run([
        ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin",
        "-f", "lavfi", "-i", "testsrc2=size=640x360:rate=30",
        "-f", "lavfi", "-i", "sine=frequency=440:sample_rate=48000",
        "-t", "75", "-c:v", "libx264", "-preset", "ultrafast",
        "-b:v", "4M", "-minrate", "4M", "-maxrate", "4M", "-bufsize", "4M",
        "-x264-params", "nal-hrd=cbr:force-cfr=1", "-pix_fmt", "yuv420p",
        "-c:a", "aac", "-b:a", "64k", "-movflags", "+faststart", str(output)
    ], check=True)
    print(f"Generated {output.name} ({output.stat().st_size} bytes)", flush=True)


if __name__ == "__main__":
    main()
