#!/usr/bin/env python3
"""Retain only symbolication fields from recent AetherFilm macOS crash reports."""
import json
from pathlib import Path


def sanitized_report(text):
    # Apple IPS files contain a one-line metadata object followed by the report.
    header, _, body = text.partition("\n")
    report = json.loads(body) if body.strip() else json.loads(header)
    if report.get("procName") != "AetherFilm":
        return None
    def fields(value, names):
        return {key: value[key] for key in names if key in value}
    result = fields(report, ("procName", "pid", "captureTime", "faultingThread", "cpuType"))
    result["exception"] = fields(report.get("exception", {}), ("type", "signal", "rawCodes"))
    result["termination"] = fields(report.get("termination", {}), ("namespace", "code"))
    result["threads"] = [
        {"triggered": thread.get("triggered", False), "frames": [
            fields(frame, ("imageIndex", "imageOffset", "symbol", "symbolLocation"))
            for frame in thread.get("frames", [])]}
        for thread in report.get("threads", [])]
    result["usedImages"] = [fields(image, ("name", "uuid", "base", "size", "arch"))
                            for image in report.get("usedImages", [])]
    return result


def collect(directory, since, output):
    records, unreadable = [], 0
    for path in Path(directory).glob("AetherFilm*.ips"):
        if path.stat().st_mtime < since:
            continue
        try:
            report = sanitized_report(path.read_text())
            if report is not None:
                records.append(report)
        except (OSError, ValueError, TypeError, AttributeError):
            unreadable += 1
    Path(output).write_text(json.dumps({"reports": records, "unreadable": unreadable}, indent=2) + "\n")


if __name__ == "__main__":
    import argparse
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--since", required=True, type=float)
    parser.add_argument("--output", required=True, type=Path)
    args = parser.parse_args()
    collect(Path.home() / "Library/Logs/DiagnosticReports", args.since, args.output)
