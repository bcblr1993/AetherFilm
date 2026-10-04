#!/usr/bin/env python3
"""Generate small, copyright-free playback fixtures with an existing ffmpeg."""

from pathlib import Path
import argparse
import hashlib
import json
import shutil
import subprocess


def generate_eof_fixture(folder, ffmpeg, ffprobe):
    """Keep the last audio packets unread while the last video frame can play."""
    output = folder / "clip-short-gop.mp4"
    metadata = folder / "clip-short-gop-tail.json"
    if output.exists() or metadata.exists():
        raise SystemExit("EOF fixtures already exist. Choose a fresh output directory.")
    # Byte offsets and the unread-picture qualification belong to this exact
    # synthetic asset. A newer host encoder must not silently replace it.
    assets = Path(__file__).resolve().parent.parent / "TestAssets" / "Playback"
    video_data = (assets / output.name).read_bytes()
    metadata_data = (assets / metadata.name).read_bytes()
    if hashlib.sha256(video_data).hexdigest() != "33e46b39e57f4e6cd56713f013dc573df8cd3b0d9debda10c4bf2a445c16bd75":
        raise SystemExit("The canonical EOF video SHA256 changed.")
    if hashlib.sha256(metadata_data).hexdigest() != "f3a569fe0218d3d1d80a7f1a12deb46d7e80eb2019fbf5e8e3e1005950110f13":
        raise SystemExit("The canonical EOF metadata SHA256 changed.")
    canonical_metadata = json.loads(metadata_data)
    with output.open("xb") as file:
        file.write(video_data)
    packets = json.loads(subprocess.check_output([
        ffprobe, "-v", "error", "-show_packets", "-show_entries",
        "packet=stream_index,pts_time,pos,size,flags", "-of", "json", str(output)
    ], text=True))["packets"]
    size = output.stat().st_size
    if not packets or any(int(p["pos"]) < 0 or int(p["size"]) <= 0
                          or int(p["pos"]) + int(p["size"]) > size for p in packets):
        raise SystemExit("The canonical EOF packet byte ranges are invalid.")
    late = [p for p in packets if float(p.get("pts_time", "-1")) >= 11.966]
    if not late:
        raise SystemExit("Generated EOF fixture has no audio tail to hold.")
    hold_at = min(int(p["pos"]) for p in late)
    video = [p for p in packets if p["stream_index"] == 0 and int(p["pos"]) + int(p["size"]) <= hold_at]
    last_video = max(float(p["pts_time"]) for p in video)
    if not 0 < hold_at < size or last_video <= 11.9:
        raise SystemExit("EOF tail layout does not preserve a real final video frame.")
    actual_metadata = {
        "fileBytes": size, "tailHoldAt": hold_at,
        "lastVideoPTSBeforeTail": last_video,
        "firstHeldPTS": min(float(p["pts_time"]) for p in late),
        "sha256": hashlib.sha256(output.read_bytes()).hexdigest()
    }
    if actual_metadata != canonical_metadata:
        raise SystemExit("ffprobe does not match the canonical EOF layout.")
    with metadata.open("xb") as file:
        file.write(metadata_data)
    print(f"Staged canonical {output.name} ({size} bytes), verified EOF tail ({size - hold_at} bytes)", flush=True)


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, default=Path(".build/PlaybackFixtures"))
    args = parser.parse_args()
    ffmpeg = shutil.which("ffmpeg")
    ffprobe = shutil.which("ffprobe")
    if ffmpeg is None or ffprobe is None:
        raise SystemExit("ffmpeg and ffprobe are required; no dependency is installed automatically.")
    folder = args.output.resolve()
    folder.mkdir(parents=True, exist_ok=True)
    (folder / "external.srt").write_text(
        "1\n00:00:00,000 --> 00:00:05,000\nAetherFilm 中文字幕测试\n\n"
        "2\n00:00:05,000 --> 00:00:12,000\n跳转后字幕仍然同步\n", encoding="utf-8")
    (folder / "external.vtt").write_text(
        "WEBVTT\n\n00:00:00.000 --> 00:00:05.000\nAetherFilm WebVTT 中文字幕\n\n"
        "00:00:05.000 --> 00:00:12.000\nWebVTT 跳转同步验证\n", encoding="utf-8")
    (folder / "external.ass").write_text(
        "[Script Info]\nScriptType: v4.00+\nPlayResX: 320\nPlayResY: 180\n"
        "[V4+ Styles]\n"
        "Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, "
        "Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, "
        "Alignment, MarginL, MarginR, MarginV, Encoding\n"
        "Style: Default,PingFang SC,18,&H00FFFFFF,&H000000FF,&H00000000,&H80000000,0,0,0,0,100,100,0,0,1,1,0,2,8,8,12,1\n"
        "[Events]\nFormat: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text\n"
        "Dialogue: 0,0:00:00.00,0:00:05.00,Default,,0,0,0,,{\\c&H00FFFF&}ASS 样式字幕\n"
        "Dialogue: 0,0:00:05.00,0:00:12.00,Default,,0,0,0,,{\\b1}跳转同步验证{\\b0}\n", encoding="utf-8")
    (folder / "chapters.ffmetadata").write_text(
        ";FFMETADATA1\n[CHAPTER]\nTIMEBASE=1/1000\nSTART=0\nEND=6000\ntitle=第一章\n"
        "[CHAPTER]\nTIMEBASE=1/1000\nSTART=6000\nEND=12000\ntitle=第二章\n", encoding="utf-8")

    def run(options, name):
        output = folder / name
        if output.exists():
            raise SystemExit(f"Fixture already exists: {output}. Use a fresh output directory.")
        subprocess.run([ffmpeg, "-hide_banner", "-loglevel", "error", "-nostdin", *options, str(output)], check=True)
        print(f"Generated {output.name} ({output.stat().st_size} bytes)", flush=True)

    inputs = ["-f", "lavfi", "-i", "testsrc2=size=320x180:rate=15", "-f", "lavfi", "-i",
              "sine=frequency=440:sample_rate=48000", "-t", "12"]
    run([*inputs, "-c:v", "libx264", "-preset", "ultrafast", "-pix_fmt", "yuv420p", "-c:a", "aac",
         "-b:a", "64k", "-movflags", "+faststart"], "clip-h264.mp4")
    run([*inputs, "-c:v", "libx265", "-preset", "ultrafast", "-x265-params", "log-level=error",
         "-tag:v", "hvc1", "-pix_fmt", "yuv420p", "-c:a", "aac", "-b:a", "64k",
         "-movflags", "+faststart"], "clip-hevc.mov")
    run([*inputs, "-c:v", "mpeg4", "-q:v", "5", "-c:a", "libmp3lame", "-b:a", "96k"], "clip-mpeg4.avi")
    run(["-i", str(folder / "clip-h264.mp4"), "-f", "lavfi", "-i", "sine=frequency=880:sample_rate=48000",
         "-i", str(folder / "external.srt"), "-i", str(folder / "external.ass"), "-f", "ffmetadata",
         "-i", str(folder / "chapters.ffmetadata"), "-map", "0:v:0", "-map", "0:a:0", "-map", "1:a:0",
         "-map", "2:s:0", "-map", "3:s:0", "-map_metadata", "4", "-map_chapters", "4", "-t", "12",
         "-c:v", "copy", "-c:a", "aac", "-b:a", "64k", "-c:s:0", "srt", "-c:s:1", "ass",
         "-metadata:s:a:0", "language=eng", "-metadata:s:a:0", "title=440Hz",
         "-metadata:s:a:1", "language=zho", "-metadata:s:a:1", "title=880Hz",
         "-metadata:s:s:0", "language=zho", "-metadata:s:s:0", "title=Embedded SRT",
         "-metadata:s:s:1", "language=zho", "-metadata:s:s:1", "title=Embedded ASS",
         "-disposition:s:0", "default", "-disposition:s:1", "0"], "clip-multitrack.mkv")
    (folder / "broken.mkv").write_bytes(b"AetherFilm malformed media fixture\n")
    generate_eof_fixture(folder, ffmpeg, ffprobe)


if __name__ == "__main__":
    main()
